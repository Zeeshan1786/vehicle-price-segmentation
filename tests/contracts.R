source("shared/schema.R")
source("shared/price_model.R")
source("backend/R/services.R")
original_model_path <- Sys.getenv("PRICE_MODEL_PATH", unset = NA_character_)
Sys.setenv(PRICE_MODEL_PATH = tempfile(fileext = ".rds"))

example <- jsonlite::fromJSON("data/example/vehicle_request.json", simplifyVector = FALSE)
stopifnot(validate_vehicle(example)$ok)
for (task in c("predict", "segment")) {
  response <- infer_vehicle(example, task)
  stopifnot(response$http_status == 503L,
            response$body$code == "MODEL_NOT_TRAINED")
}

invalid <- example
invalid$year <- 2018.5
stopifnot(!validate_vehicle(invalid)$ok)
invalid <- example
invalid$km_driven <- -1
stopifnot(infer_vehicle(invalid, "predict")$http_status == 422L)
invalid <- example
invalid$fuel <- "unsupported"
stopifnot(!validate_vehicle(invalid)$ok)
invalid <- example
invalid$seats <- "5"
stopifnot(!validate_vehicle(invalid)$ok)
invalid <- example
invalid$brand <- NULL
stopifnot(!validate_vehicle(invalid)$ok)
invalid <- example
invalid$selling_price <- 100000
stopifnot(!validate_vehicle(invalid)$ok)
invalid <- example
invalid$year <- list(2018)
stopifnot(!validate_vehicle(invalid)$ok)
stopifnot(!validate_vehicle(list())$ok, !validate_vehicle(list(example))$ok)

res <- new.env(parent = emptyenv())
res$status <- 200L
invalid_json <- handle_inference(list(postBody = "{broken"), res, "predict")
stopifnot(res$status == 400L, invalid_json$code == "INVALID_JSON")
res$status <- 200L
valid_json <- handle_inference(
  list(postBody = paste(readLines("data/example/vehicle_request.json"), collapse = "\n")),
  res, "predict")
stopifnot(res$status == 503L, valid_json$code == "MODEL_NOT_TRAINED")
stopifnot(identical(model_status()$inference_enabled, FALSE))
if (is.na(original_model_path)) Sys.unsetenv("PRICE_MODEL_PATH") else Sys.setenv(PRICE_MODEL_PATH = original_model_path)
message("Contract checks passed.")
