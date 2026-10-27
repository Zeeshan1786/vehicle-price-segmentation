api_request <- function(path, body = NULL) {
  base <- sub("/+$", "", Sys.getenv("API_BASE_URL", "http://127.0.0.1:8000"))
  tryCatch({
    request <- httr2::request(paste0(base, path))
    request <- httr2::req_timeout(request, seconds = 5)
    request <- httr2::req_error(request, is_error = function(resp) FALSE)
    if (!is.null(body)) request <- httr2::req_body_json(request, body, auto_unbox = TRUE)
    response <- httr2::req_perform(request)
    payload <- httr2::resp_body_json(response, simplifyVector = FALSE)
    list(ok = httr2::resp_status(response) < 400L,
         status = httr2::resp_status(response), body = payload)
  }, error = function(e) {
    list(ok = FALSE, status = 0L, body = list(
      code = "API_UNAVAILABLE",
      message = "The API is unavailable. Start the backend and check API_BASE_URL."))
  })
}
