#* @apiTitle Vehicle Price and Segmentation API
#* @apiDescription Historical vehicle listing-price prediction with an R linear regression baseline.
#* @serializer unboxedJSON

#* Health check; healthy does not mean inference-ready
#* @get /health
function() {
  list(status = "ok", phase = model_status()$phase, models = model_status())
}

#* Feature definitions and a synthetic input example
#* @get /schema
function() {
  bundle <- load_price_model()
  list(schema_version = "1.1", currency = "INR",
       fields = if (is.null(bundle)) vehicle_schema() else bundle$input_options$fields,
       example = if (is.null(bundle)) vehicle_example() else bundle$input_options$example)
}

#* Dataset-backed predictor input options and held-out evaluation
#* @get /predictor/options
function(res) {
  bundle <- load_price_model()
  if (is.null(bundle)) {
    res$status <- 503L
    return(error_body("MODEL_NOT_TRAINED", "The price predictor is not available yet."))
  }
  bundle$input_options
}

#* Model readiness
#* @get /models/status
function() {
  model_status()
}

#* Future segment profiles
#* @get /segments
function(res) {
  res$status <- 503L
  error_body("MODEL_NOT_TRAINED", "Segment profiles are unavailable until training.")
}

#* Estimate historical listing price with the trained linear regression
#* @post /predict
function(req, res) {
  handle_inference(req, res, "predict")
}

#* Request a future segment assignment
#* @post /segment
function(req, res) {
  handle_inference(req, res, "segment")
}

#* Local dataset status and audit summary
#* @get /data/status
function() {
  dataset <- load_dataset()
  if (!dataset$ready) return(dataset)
  dataset[c("ready", "source", "report", "missingness")]
}

#* Audited local dataset for the dashboard; no training occurs
#* @get /data/vehicles
function(res) {
  dataset <- load_dataset()
  if (!dataset$ready) {
    res$status <- 503L
    return(error_body("DATASET_NOT_READY", dataset$message))
  }
  dataset
}

#* Audit an uploaded CSV in memory without persisting it
#* @post /data/preview
function(req, res) {
  if (is.null(req$postBody) || nchar(req$postBody, type = "bytes") > 15 * 1024^2) {
    res$status <- 413L
    return(error_body("CSV_SIZE_LIMIT", "Upload a CSV smaller than 15 MB."))
  }
  tryCatch({
    raw <- read.csv(text = req$postBody, stringsAsFactors = FALSE,
                    check.names = FALSE, na.strings = c("", "NA"))
    prepared <- prepare_vehicles(raw)
    c(list(ready = TRUE, source = "Uploaded CSV / current session only"), prepared)
  }, error = function(e) {
    res$status <- 422L
    error_body("INVALID_DATASET", conditionMessage(e))
  })
}
