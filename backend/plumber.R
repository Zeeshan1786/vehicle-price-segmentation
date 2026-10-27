#* @apiTitle Vehicle Price and Segmentation API
#* @apiDescription Structure-phase API. No models have been trained.
#* @serializer unboxedJSON

#* Health check; healthy does not mean inference-ready
#* @get /health
function() {
  list(status = "ok", phase = "exploration", models = model_status())
}

#* Feature definitions and a synthetic input example
#* @get /schema
function() {
  list(schema_version = "1.0", currency = "INR",
       fields = vehicle_schema(), example = vehicle_example())
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

#* Request a future price estimate
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
