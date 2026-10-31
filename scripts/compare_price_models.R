if (!file.exists("shared/schema.R")) stop("Run comparison from the repository root.")
dir.create("data/processed/model_comparison", recursive = TRUE, showWarnings = FALSE)
source("shared/schema.R")
source("shared/price_model.R")
source("backend/R/data.R")
stopifnot(requireNamespace("ranger", quietly = TRUE))
baseline <- readRDS("models/linear_baseline.rds")
stopifnot(baseline$artifact_schema == "price-lm-v1")
dataset <- load_dataset()
stopifnot(dataset$ready)
vehicles <- dataset$vehicles
group_columns <- c("brand", "model", price_numeric_fields, price_category_fields)
fingerprints <- do.call(paste, c(lapply(vehicles[group_columns], as.character), sep = "|"))
group_ids <- match(fingerprints, unique(fingerprints))
set.seed(2026)
groups <- sort(unique(group_ids))
train_groups <- sample(groups, floor(.8 * length(groups)))
is_train <- group_ids %in% train_groups
train <- vehicles[is_train, , drop = FALSE]
test <- vehicles[!is_train, , drop = FALSE]
stopifnot(nrow(train) == baseline$training$train_rows, nrow(test) == baseline$training$test_rows)

score <- function(actual, predicted) list(mae_inr = unname(mean(abs(actual - predicted))),
  rmse_inr = unname(sqrt(mean((actual - predicted)^2))),
  r_squared = unname(1 - sum((actual - predicted)^2) / sum((actual - mean(actual))^2)))

configs <- expand.grid(mtry = c(4L, 8L, 11L), min_node_size = c(3L, 5L))
configs$model <- paste0("rf_m", configs$mtry, "_node", configs$min_node_size)
predictions <- matrix(NA_real_, nrow(train), nrow(configs) + 1L,
  dimnames = list(NULL, c("linear_regression", configs$model)))
set.seed(2027)
fold_groups <- sample(unique(group_ids[is_train]))
fold_lookup <- setNames(rep(1:5, length.out = length(fold_groups)), fold_groups)
fold_id <- unname(fold_lookup[as.character(group_ids[is_train])])

for (fold in 1:5) {
  analysis <- train[fold_id != fold, , drop = FALSE]
  assessment <- train[fold_id == fold, , drop = FALSE]
  prep <- fit_price_preprocessor(analysis)
  frame <- prepare_price_frame(analysis, prep)
  frame$selling_price_inr <- analysis$selling_price_inr
  fit <- stats::lm(stats::as.formula(paste("selling_price_inr", baseline$design_formula)), data = frame)
  coefs <- stats::coef(fit)
  coefs[is.na(coefs)] <- 0
  linear <- list(preprocessor = prep, design_formula = baseline$design_formula,
                 contrasts = fit$contrasts, coefficients = coefs)
  predictions[fold_id == fold, "linear_regression"] <- predict_price_values(linear, assessment)
  prep_rf <- fit_forest_prep(analysis)
  frame_rf <- prepare_forest_frame(analysis, prep_rf)
  target <- analysis$selling_price_inr
  assessment_rf <- prepare_forest_frame(assessment, prep_rf)
  for (config in seq_len(nrow(configs))) {
    forest <- ranger::ranger(x = frame_rf, y = target, num.trees = 500,
      mtry = configs$mtry[[config]], min.node.size = configs$min_node_size[[config]],
      respect.unordered.factors = "order", num.threads = 2, seed = 2028 + fold,
      oob.error = FALSE, write.forest = TRUE)
    predictions[fold_id == fold, configs$model[[config]]] <- predict(forest, assessment_rf, num.threads = 2)$predictions
  }
  cat("Completed training-only grouped CV fold", fold, "of 5\n")
  flush.console()
}
stopifnot(all(is.finite(predictions)))
cv_results <- do.call(rbind, lapply(colnames(predictions), function(name) {
  data.frame(model = name, as.data.frame(score(train$selling_price_inr, predictions[, name])))
}))
cv_results <- cv_results[order(cv_results$rmse_inr), ]
print(cv_results)
selection <- cv_results$model[[1]]
# Persist model selection before inspecting the unchanged final test labels.
jsonlite::write_json(list(selection = selection, folds = 5, fold_seed = 2027L,
  criterion = "Minimum pooled out-of-fold RMSE on training records", results = cv_results,
  configs = configs), "data/processed/model_comparison/price_model_cv_selection.json", pretty = TRUE, auto_unbox = TRUE)
if (selection == "linear_regression") stop("Cross-validation did not support replacing the linear baseline.")
config <- configs[configs$model == selection, ]
prep_rf <- fit_forest_prep(train)
forest <- ranger::ranger(x = prepare_forest_frame(train, prep_rf), y = train$selling_price_inr,
  num.trees = 500, mtry = config$mtry, min.node.size = config$min_node_size,
  respect.unordered.factors = "order", num.threads = 2, seed = 2034,
  importance = "permutation", oob.error = TRUE, write.forest = TRUE)
estimates <- predict(forest, prepare_forest_frame(test, prep_rf), num.threads = 2)$predictions
stopifnot(length(estimates) == nrow(test), all(is.finite(estimates)), all(estimates > 0))
metrics <- list(model = score(test$selling_price_inr, estimates),
  linear_baseline = baseline$metrics$model, median_baseline = baseline$metrics$median_baseline,
  test_nonpositive_predictions = sum(estimates <= 0),
  note = "Selected using training-only grouped CV, then evaluated on the unchanged original test set. No test rows or predictions were clipped or removed.")
forest$predictions <- NULL
forest$call <- NULL
bundle <- baseline
bundle$artifact_schema <- "price-ranger-v1"
bundle$model_version <- "random-forest-v1"
bundle$algorithm <- "ranger"
bundle$algorithm_label <- "Random forest (R ranger)"
bundle$coefficients <- bundle$contrasts <- bundle$design_formula <- NULL
bundle$forest <- forest
bundle$preprocessor <- prep_rf
bundle$metrics <- metrics
bundle$training$selection <- list(folds = 5L, fold_seed = 2027L, criterion = "Training-only grouped CV RMSE",
  selected_config = as.list(config), cv_results = cv_results, trees = 500L, forest_seed = 2034L)
bundle$training$family_pooling <- "Manufacturer plus first model token; fewer than 3 training rows pooled. Brand is also included."
bundle$training$rank <- NULL
bundle$created_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
bundle$input_options$model_version <- bundle$model_version
bundle$input_options$algorithm_label <- bundle$algorithm_label
bundle$input_options$metrics <- metrics
bundle$input_options$training <- bundle$training
saveRDS(bundle, "data/processed/model_comparison/best_price_candidate.rds", compress = "xz")
jsonlite::write_json(list(metrics = metrics, training = bundle$training,
  source_sha256 = bundle$source_sha256), "data/processed/model_comparison/best_price_candidate_metrics.json", pretty = TRUE, auto_unbox = TRUE, digits = 8)
write.csv(data.frame(actual_inr = test$selling_price_inr, predicted_inr = estimates),
  "data/processed/model_comparison/forest_test_predictions.csv", row.names = FALSE)
print(metrics)
cat("Candidate saved separately; the deployed predictor is unchanged.\n")
