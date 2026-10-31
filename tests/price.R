source("shared/schema.R")
source("shared/price_model.R")
source("backend/R/services.R")
bundle <- load_price_model()
stopifnot(!is.null(bundle), bundle$training$group_overlap == 0L,
          !any(c("model", "qr", "residuals", "fitted.values") %in% names(bundle)),
          bundle$metrics$model$mae_inr < bundle$metrics$linear_baseline$mae_inr,
          bundle$model_version == "random-forest-v1", is.null(bundle$forest$predictions),
          bundle$training$selection$folds == 5L)
example <- bundle$input_options$example
result <- infer_vehicle(example, "predict")
stopifnot(result$http_status == 200L, result$body$predicted_price_inr > 0,
          result$body$model_version == bundle$model_version,
          infer_vehicle(example, "segment")$http_status == 503L)
older <- example
older$year <- older$year - 3L
stopifnot(infer_vehicle(older, "predict")$http_status == 200L)
invalid <- example
invalid$model <- "Not a dataset model"
stopifnot(infer_vehicle(invalid, "predict")$http_status == 422L)
invalid <- example
invalid$km_driven <- -1
stopifnot(infer_vehicle(invalid, "predict")$http_status == 422L)
extreme <- example
extreme$year <- bundle$input_options$fields$year$min
extreme$km_driven <- bundle$input_options$fields$km_driven$max
unsupported <- infer_vehicle(extreme, "predict")
stopifnot(unsupported$http_status == 200L, unsupported$body$predicted_price_inr > 0)
baseline <- readRDS("models/linear_baseline.rds")
stopifnot(predict_price_values(baseline, as.data.frame(example)) > 0)
message("Selected random forest, preserved linear baseline and prediction checks passed.")
