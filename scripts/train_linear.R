if (!file.exists("shared/schema.R")) stop("Run training from the repository root.")
source("shared/schema.R")
source("shared/price_model.R")
source("backend/R/data.R")
dataset <- load_dataset()
if (!dataset$ready) stop(dataset$message)
vehicles <- dataset$vehicles
# Matching inference profiles, including different price labels, must stay in one split.
group_columns <- c("brand", "model", price_numeric_fields, price_category_fields)
fingerprints <- do.call(paste, c(lapply(vehicles[group_columns], as.character), sep = "|"))
group_ids <- match(fingerprints, unique(fingerprints))
set.seed(2026)
groups <- sort(unique(group_ids))
train_groups <- sample(groups, floor(.8 * length(groups)))
is_train <- group_ids %in% train_groups
train <- vehicles[is_train, , drop = FALSE]
test <- vehicles[!is_train, , drop = FALSE]
stopifnot(length(intersect(group_ids[is_train], group_ids[!is_train])) == 0L)
prep <- fit_price_preprocessor(train)
frame <- prepare_price_frame(train, prep)
frame$selling_price_inr <- train$selling_price_inr
design <- "~ vehicle_group + year + km_driven + fuel + seller_type + transmission + owner + engine_cc + max_power_bhp + seats"
fit <- stats::lm(stats::as.formula(paste("selling_price_inr", design)), data = frame)
stopifnot(!anyNA(stats::coef(fit)), fit$rank == length(stats::coef(fit)))
bundle <- list(artifact_schema = "price-lm-v1", model_version = "linear-regression-v1",
  algorithm = "stats::lm", design_formula = design, coefficients = stats::coef(fit), contrasts = fit$contrasts,
  preprocessor = prep, reference_year = dataset$report$reference_year,
  created_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  training = list(seed = 2026L, split = "80/20 inference-profile group split", train_rows = nrow(train),
    test_rows = nrow(test), train_groups = length(unique(group_ids[is_train])),
    test_groups = length(unique(group_ids[!is_train])), group_overlap = 0L, rank = fit$rank,
    imputation = "Training medians; zero power treated as missing",
    family_pooling = "Manufacturer plus first model token; fewer than 10 training rows pooled"))
stopifnot(isTRUE(all.equal(predict_price_values(bundle, train), as.numeric(stats::predict(fit)),
                          check.attributes = FALSE, tolerance = 1e-8)))
score <- function(actual, predicted) list(mae_inr = unname(mean(abs(actual - predicted))),
  rmse_inr = unname(sqrt(mean((actual - predicted)^2))),
  r_squared = unname(1 - sum((actual - predicted)^2) / sum((actual - mean(actual))^2)))
estimates <- predict_price_values(bundle, test)
stopifnot(all(is.finite(estimates)))
bundle$metrics <- list(model = score(test$selling_price_inr, estimates),
  median_baseline = score(test$selling_price_inr, rep(median(train$selling_price_inr), nrow(test))),
  test_nonpositive_predictions = sum(estimates <= 0),
  note = "Test metrics use raw predictions without clipping. Nonpositive interactive estimates are rejected.")
fields <- vehicle_schema()
for (field in c("brand", price_category_fields)) fields[[field]]$choices <- sort(unique(vehicles[[field]]))
for (field in price_numeric_fields) {
  valid <- vehicles[[field]][is.finite(vehicles[[field]])]
  if (field == "max_power_bhp") valid <- valid[valid > 0]
  fields[[field]]$min <- min(valid)
  fields[[field]]$max <- max(valid)
}
fields$year$choices <- sort(unique(vehicles$year))
fields$seats$choices <- sort(unique(vehicles$seats[is.finite(vehicles$seats)]))
fields$model$choices <- sort(unique(vehicles$model))
example <- vehicle_example()
stopifnot(example$model %in% vehicles$model)
bundle$input_options <- list(fields = fields,
  models_by_brand = lapply(split(vehicles$model, vehicles$brand), function(x) sort(unique(x))),
  example = example, metrics = bundle$metrics, training = bundle$training,
  model_version = bundle$model_version,
  omitted_source_fields = c("selling_price is the target", "mileage and torque omitted from this baseline because their source units/formats vary"))
stopifnot(predict_price_values(bundle, as.data.frame(example)) > 0)
source_path <- Sys.getenv("VEHICLE_DATA_PATH", file.path("data", "raw", "Car details v3.csv"))
connection <- file(source_path, "rb")
bundle$source_sha256 <- paste0(openssl::sha256(connection))
close(connection)
dir.create("models", showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
# Store only coefficients and preprocessing/aggregate metadata, not lm's per-row model/QR/residuals.
saveRDS(bundle, "models/linear_baseline.rds", compress = "xz")
jsonlite::write_json(list(model_version = bundle$model_version, training = bundle$training,
  metrics = bundle$metrics, source_sha256 = bundle$source_sha256),
  "models/linear_metrics.json", auto_unbox = TRUE, pretty = TRUE, digits = 8)
write.csv(data.frame(source_row_id = vehicles$source_row_id, duplicate_group_id = group_ids,
  split = ifelse(is_train, "train", "test")), "data/processed/price_split_manifest.csv", row.names = FALSE)
write.csv(data.frame(actual_inr = test$selling_price_inr, predicted_inr = estimates),
  "data/processed/price_test_predictions.csv", row.names = FALSE)
jsonlite::write_json(example, "data/example/vehicle_request.json", auto_unbox = TRUE, pretty = TRUE)
print(bundle$training)
print(bundle$metrics)
message("Linear regression baseline trained, evaluated and saved separately.")
