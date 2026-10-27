vehicle_schema <- function() {
  list(
    brand = list(type = "string", label = "Brand", example = "Maruti", max_length = 80),
    model = list(type = "string", label = "Model / variant", example = "Swift", max_length = 160),
    year = list(type = "integer", label = "Manufacturing year", min = 1980,
                max = as.integer(format(Sys.Date(), "%Y"))),
    km_driven = list(type = "number", label = "Distance driven (km)", min = 0, max = 2000000),
    fuel = list(type = "string", label = "Fuel", choices = c("Petrol", "Diesel", "CNG", "LPG")),
    seller_type = list(type = "string", label = "Seller type",
                       choices = c("Individual", "Dealer", "Trustmark Dealer")),
    transmission = list(type = "string", label = "Transmission", choices = c("Manual", "Automatic")),
    owner = list(type = "string", label = "Ownership",
                 choices = c("First Owner", "Second Owner", "Third Owner",
                             "Fourth & Above Owner", "Test Drive Car")),
    engine_cc = list(type = "number", label = "Engine (cc)", min = 300, max = 10000),
    max_power_bhp = list(type = "number", label = "Maximum power (bhp)", min = 1, max = 1500),
    seats = list(type = "integer", label = "Seats", min = 2, max = 14)
  )
}

vehicle_example <- function() {
  list(brand = "Maruti", model = "Swift Dzire VDI", year = 2018L, km_driven = 45000,
       fuel = "Diesel", seller_type = "Individual", transmission = "Manual",
       owner = "First Owner", engine_cc = 1248, max_power_bhp = 74, seats = 5L)
}

validate_vehicle <- function(x, schema = vehicle_schema()) {
  errors <- character()
  if (!is.list(x) || is.null(names(x)) || anyDuplicated(names(x)) > 0L) {
    return(list(ok = FALSE, errors = "Body must be one JSON object with unique field names."))
  }
  extra <- setdiff(names(x), names(schema))
  if (length(extra)) errors <- c(errors, paste("Unknown fields:", paste(extra, collapse = ", ")))
  for (field in names(schema)) {
    spec <- schema[[field]]
    value <- x[[field]]
    if (is.null(value) || length(value) != 1L || is.list(value) || anyNA(value)) {
      errors <- c(errors, paste(field, "is required and must be a non-null scalar."))
      next
    }
    if (spec$type == "string") {
      if (!is.character(value) || !nzchar(trimws(value))) {
        errors <- c(errors, paste(field, "must be a non-empty string."))
      } else {
        if (!is.null(spec$max_length) && nchar(value) > spec$max_length)
          errors <- c(errors, paste(field, "is too long."))
        if (!is.null(spec$choices) && !(value %in% spec$choices))
          errors <- c(errors, paste(field, "is not an allowed category."))
      }
    } else {
      if (!is.numeric(value) || !is.finite(value)) {
        errors <- c(errors, paste(field, "must be a finite number."))
      } else {
        if (value < spec$min || value > spec$max)
          errors <- c(errors, paste(field, "is outside the allowed range."))
        if (spec$type == "integer" && value != floor(value))
          errors <- c(errors, paste(field, "must be a whole number."))
      }
    }
  }
  list(ok = length(errors) == 0L, errors = errors)
}
