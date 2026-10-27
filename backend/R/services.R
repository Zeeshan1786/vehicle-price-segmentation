model_status <- function() {
  # File presence alone must never mark an unvalidated model as ready.
  list(price_model = "not_trained", segmentation_model = "not_trained",
       inference_enabled = FALSE, phase = "structure")
}

error_body <- function(code, message, details = character()) {
  list(status = "error", code = code, message = message, details = as.list(details))
}

infer_vehicle <- function(vehicle, task) {
  if (!(task %in% c("predict", "segment"))) stop("Unsupported service task.")
  validation <- validate_vehicle(vehicle)
  if (!validation$ok) {
    return(list(http_status = 422L, body = error_body(
      "VALIDATION_ERROR", "Please correct the vehicle details.", validation$errors)))
  }
  list(http_status = 503L, body = error_body(
    "MODEL_NOT_TRAINED",
    if (task == "predict") "Price prediction will be available after model training."
    else "Vehicle segments will be available after clustering is trained."))
}

handle_inference <- function(req, res, task) {
  body <- tryCatch(
    jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(body)) {
    res$status <- 400L
    return(error_body("INVALID_JSON", "Send one valid JSON object."))
  }
  result <- infer_vehicle(body, task)
  res$status <- result$http_status
  result$body
}
