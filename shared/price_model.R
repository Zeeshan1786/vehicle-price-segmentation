price_numeric_fields <- c("year", "km_driven", "engine_cc", "max_power_bhp", "seats")
price_category_fields <- c("fuel", "seller_type", "transmission", "owner")

vehicle_family <- function(d) paste(d$brand, sub(" .*", "", d$model))

fit_price_preprocessor <- function(train) {
  medians <- vapply(train[price_numeric_fields], function(x) {
    x[!is.finite(x)] <- NA_real_
    median(x, na.rm = TRUE)
  }, numeric(1))
  medians[["max_power_bhp"]] <- median(train$max_power_bhp[is.finite(train$max_power_bhp) & train$max_power_bhp > 0])
  families <- table(vehicle_family(train))
  retained <- names(families)[families >= 10L]
  family_levels <- sort(unique(ifelse(vehicle_family(train) %in% retained,
                                      vehicle_family(train), "Other vehicle families")))
  levels <- lapply(train[price_category_fields], function(x) sort(unique(x[!is.na(x) & nzchar(x)])))
  modes <- vapply(train[price_category_fields], function(x) names(sort(table(x), decreasing = TRUE))[[1]], character(1))
  list(medians = medians, retained_families = retained, family_levels = family_levels,
       category_levels = levels, category_modes = modes,
       ranges = lapply(train[price_numeric_fields], function(x) range(x[is.finite(x)], na.rm = TRUE)))
}

prepare_price_frame <- function(d, prep) {
  result <- d[price_numeric_fields]
  for (field in price_numeric_fields) {
    missing <- !is.finite(result[[field]])
    if (field == "max_power_bhp") missing <- missing | result[[field]] <= 0
    result[[field]][missing] <- prep$medians[[field]]
  }
  family <- vehicle_family(d)
  family[!(family %in% prep$retained_families)] <- "Other vehicle families"
  result$vehicle_group <- factor(family, levels = prep$family_levels)
  for (field in price_category_fields) {
    value <- as.character(d[[field]])
    value[is.na(value) | !(value %in% prep$category_levels[[field]])] <- prep$category_modes[[field]]
    result[[field]] <- factor(value, levels = prep$category_levels[[field]])
  }
  result
}

fit_forest_prep <- function(d) {
  prep <- fit_price_preprocessor(d)
  families <- table(vehicle_family(d))
  prep$retained_families <- names(families)[families >= 3L]
  values <- ifelse(vehicle_family(d) %in% prep$retained_families, vehicle_family(d), "Other vehicle families")
  prep$family_levels <- sort(unique(values))
  counts <- table(d$brand)
  prep$retained_brands <- names(counts)[counts >= 3L]
  brands <- ifelse(d$brand %in% prep$retained_brands, d$brand, "Other brands")
  prep$brand_levels <- sort(unique(brands))
  prep$brand_fallback <- if ("Other brands" %in% prep$brand_levels) "Other brands" else names(sort(counts, decreasing = TRUE))[[1]]
  prep
}
prepare_forest_frame <- function(d, prep) {
  result <- prepare_price_frame(d, prep)
  brands <- ifelse(d$brand %in% prep$retained_brands, d$brand, prep$brand_fallback)
  result$brand <- factor(brands, levels = prep$brand_levels)
  result
}

predict_price_values <- function(bundle, d) {
  if (identical(bundle$artifact_schema, "price-ranger-v1")) {
    if (!requireNamespace("ranger", quietly = TRUE)) stop("Install ranger to use the trained forest.")
    return(as.numeric(predict(bundle$forest, prepare_forest_frame(d, bundle$preprocessor), num.threads = 2)$predictions))
  }
  frame <- prepare_price_frame(d, bundle$preprocessor)
  matrix <- stats::model.matrix(stats::as.formula(bundle$design_formula), frame, contrasts.arg = bundle$contrasts)
  as.numeric(matrix[, names(bundle$coefficients), drop = FALSE] %*% bundle$coefficients)
}

price_model_cache <- new.env(parent = emptyenv())
load_price_model <- function() {
  path <- Sys.getenv("PRICE_MODEL_PATH", file.path(Sys.getenv("VEHICLE_PROJECT_ROOT", "."), "models", "price_model.rds"))
  if (!file.exists(path)) return(NULL)
  stamp <- paste(normalizePath(path), file.info(path)$mtime, file.info(path)$size)
  if (identical(price_model_cache$stamp, stamp)) return(price_model_cache$bundle)
  bundle <- tryCatch({
    value <- readRDS(path)
    stopifnot(value$artifact_schema %in% c("price-lm-v1", "price-ranger-v1"),
              is.list(value$input_options), is.list(value$preprocessor))
    if (value$artifact_schema == "price-lm-v1") {
      stopifnot(is.numeric(value$coefficients), all(is.finite(value$coefficients)),
        identical(value$design_formula, "~ vehicle_group + year + km_driven + fuel + seller_type + transmission + owner + engine_cc + max_power_bhp + seats"))
    } else {
      stopifnot(requireNamespace("ranger", quietly = TRUE), inherits(value$forest, "ranger"),
                !is.null(value$forest$forest), is.null(value$forest$predictions))
    }
    check <- predict_price_values(value, as.data.frame(value$input_options$example, stringsAsFactors = FALSE))
    stopifnot(length(check) == 1L, is.finite(check), check > 0)
    value
  }, error = function(e) NULL)
  price_model_cache$stamp <- stamp
  price_model_cache$bundle <- bundle
  bundle
}

predict_vehicle_price <- function(vehicle, bundle) {
  validation <- validate_vehicle(vehicle, bundle$input_options$fields)
  if (!validation$ok) return(list(http_status = 422L, body = error_body(
    "VALIDATION_ERROR", "Please correct the vehicle details.", validation$errors)))
  if (!(vehicle$model %in% bundle$input_options$models_by_brand[[vehicle$brand]])) {
    return(list(http_status = 422L, body = error_body("VALIDATION_ERROR", "Select a model offered for this manufacturer.")))
  }
  frame <- as.data.frame(vehicle, stringsAsFactors = FALSE)
  value <- predict_price_values(bundle, frame)
  if (length(value) != 1L || !is.finite(value) || value <= 0) {
    return(list(http_status = 422L, body = error_body("UNSUPPORTED_ESTIMATE",
      "The model cannot produce a positive estimate for this combination. Check the specifications or use a dataset example.")))
  }
  warnings <- c("Historical listing-price estimate in INR; not a current market valuation or completed sale price.",
                "Individual vehicle condition and accident history are unavailable; estimates can still be inaccurate.")
  if (!(vehicle_family(frame) %in% bundle$preprocessor$retained_families)) {
    warnings <- c(warnings, "This vehicle family is rare and uses the pooled vehicle-family group.")
  }
  for (field in price_category_fields) {
    if (!(vehicle[[field]] %in% bundle$preprocessor$category_levels[[field]])) {
      warnings <- c(warnings, paste(field, "was absent from training; its training-mode fallback was used."))
    }
  }
  for (field in price_numeric_fields) {
    limits <- bundle$preprocessor$ranges[[field]]
    if (vehicle[[field]] < limits[[1]] || vehicle[[field]] > limits[[2]]) {
      warnings <- c(warnings, paste(field, "is outside the training range; the estimate extrapolates."))
    }
  }
  list(http_status = 200L, body = list(status = "ok", predicted_price_inr = round(value),
    currency = "INR", model_version = bundle$model_version, algorithm = if (is.null(bundle$algorithm_label)) "Multiple linear regression (R stats::lm)" else bundle$algorithm_label,
    schema_version = "1.1", test_metrics = bundle$metrics$model,
    warnings = as.list(warnings)))
}
