#* @apiTitle Vehicle Price and Segmentation API
#* @apiDescription Structure-phase API. No models have been trained.
#* @serializer unboxedJSON

#* Health check; healthy does not mean inference-ready
#* @get /health
function() {
  list(status = "ok", phase = "structure", models = model_status())
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
