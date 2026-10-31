if (!file.exists("shared/schema.R")) stop("Run training from the repository root.")
if (!requireNamespace("ranger", quietly = TRUE)) stop("Run scripts/setup.R to install ranger.")

# Preserve and reproduce the original linear model on the exact same split.
source("scripts/train_linear.R")
linear_bundle <- bundle
linear_fit <- fit
selection <- jsonlite::fromJSON("models/model_selection.json")
stopifnot(identical(selection$source_sha256, linear_bundle$source_sha256))
config <- selection$configs[selection$configs$model == selection$selection, , drop = FALSE]
stopifnot(nrow(config) == 1L)

# Settings were selected by five-fold grouped CV using training records only.
# This command reproduces the selected model; full CV is in compare_price_models.R.
prep <- fit_forest_prep(train)
frame <- prepare_forest_frame(train, prep)
fit <- ranger::ranger(
  x = frame, y = train$selling_price_inr,
  num.trees = selection$trees, mtry = config$mtry,
  min.node.size = config$min_node_size,
  respect.unordered.factors = "order", num.threads = 2,
  seed = selection$forest_seed, importance = "permutation",
  oob.error = TRUE, write.forest = TRUE
)
estimates <- predict(fit, prepare_forest_frame(test, prep), num.threads = 2)$predictions
stopifnot(length(estimates) == nrow(test), all(is.finite(estimates)), all(estimates > 0))

bundle <- linear_bundle
bundle$artifact_schema <- "price-ranger-v1"
bundle$model_version <- "random-forest-v1"
bundle$algorithm <- "ranger"
bundle$algorithm_label <- "Random forest (R ranger)"
bundle$coefficients <- bundle$contrasts <- bundle$design_formula <- NULL
bundle$forest <- fit
bundle$forest$predictions <- NULL
bundle$forest$call <- NULL
bundle$preprocessor <- prep
bundle$metrics <- list(
  model = score(test$selling_price_inr, estimates),
  linear_baseline = linear_bundle$metrics$model,
  median_baseline = linear_bundle$metrics$median_baseline,
  test_nonpositive_predictions = sum(estimates <= 0),
  note = "Selected using training-only grouped CV, then evaluated on the unchanged original test set. No test records or estimates were clipped or removed. This previously viewed test set is a fixed benchmark, not a new external audit."
)
bundle$training$rank <- NULL
bundle$training$family_pooling <- "Manufacturer plus first model token; fewer than 3 training rows pooled. Brand is also included."
bundle$training$selection <- list(folds = selection$folds, fold_seed = selection$fold_seed,
  criterion = selection$criterion, selected_config = as.list(config),
  cv_results = selection$results, trees = selection$trees, forest_seed = selection$forest_seed)
bundle$created_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
bundle$input_options$model_version <- bundle$model_version
bundle$input_options$algorithm_label <- bundle$algorithm_label
bundle$input_options$metrics <- bundle$metrics
bundle$input_options$training <- bundle$training

example <- vehicle_example()
stopifnot(predict_price_values(bundle, as.data.frame(example)) > 0)
saveRDS(bundle, "models/price_model.rds", compress = "xz")
jsonlite::write_json(list(model_version = bundle$model_version, algorithm = bundle$algorithm_label,
  training = bundle$training, metrics = bundle$metrics, source_sha256 = bundle$source_sha256),
  "models/metrics.json", auto_unbox = TRUE, pretty = TRUE, digits = 8)
write.csv(data.frame(actual_inr = test$selling_price_inr, predicted_inr = estimates),
  "data/processed/price_test_predictions.csv", row.names = FALSE)
print(fit)
cat("\nHELD-OUT TEST METRICS (not training or OOB scores)\n")
print(bundle$metrics)
message("Random forest trained in R and saved. Linear regression retained as a baseline.")
