numeric_prefix <- function(x) {
  suppressWarnings(as.numeric(sub("[^0-9.].*$", "", trimws(as.character(x)))))
}

prepare_vehicles <- function(raw) {
  required <- c("name", "year", "selling_price", "km_driven", "fuel", "seller_type",
                "transmission", "owner", "engine", "max_power", "seats")
  absent <- setdiff(required, names(raw))
  if (length(absent)) stop(paste("Missing source columns:", paste(absent, collapse = ", ")))
  raw[] <- lapply(raw, function(x) if (is.character(x)) trimws(x) else x)
  missingness <- data.frame(field = names(raw), missing = vapply(raw, function(x) {
    sum(is.na(x) | trimws(as.character(x)) == "")
  }, integer(1)), total = nrow(raw), row.names = NULL)
  duplicate <- duplicated(raw)
  source_rows <- which(!duplicate)
  clean <- raw[!duplicate, , drop = FALSE]
  manufacturers <- c("Ashok Leyland", "Land Rover", "Mercedes-Benz", "Maruti", "Hyundai",
    "Tata", "Mahindra", "Ford", "Honda", "Toyota", "Volkswagen", "BMW", "Chevrolet",
    "Skoda", "Audi", "Datsun", "Fiat", "Nissan", "Renault", "Jeep", "Kia", "MG",
    "Mitsubishi", "Volvo", "Lexus", "Force", "Isuzu", "Ambassador", "Daewoo", "Jaguar",
    "Opel", "Bentley")
  brands <- vapply(as.character(clean$name), function(name) {
    if (is.na(name) || !nzchar(name)) return("Unknown")
    hit <- manufacturers[vapply(manufacturers, function(brand) {
      identical(name, brand) || startsWith(name, paste0(brand, " "))
    }, logical(1))]
    if (length(hit)) hit[[1]] else "Unknown"
  }, character(1))
  values <- data.frame(
    source_row_id = source_rows, name = as.character(clean$name), brand = brands,
    year = numeric_prefix(clean$year), selling_price_inr = numeric_prefix(clean$selling_price),
    km_driven = numeric_prefix(clean$km_driven), fuel = as.character(clean$fuel),
    seller_type = as.character(clean$seller_type), transmission = as.character(clean$transmission),
    owner = as.character(clean$owner), engine_cc = numeric_prefix(clean$engine),
    max_power_bhp = numeric_prefix(clean$max_power), seats = numeric_prefix(clean$seats),
    stringsAsFactors = FALSE)
  # Validate signed source numbers before parsing unit-bearing fields.
  values$year <- suppressWarnings(as.numeric(clean$year))
  values$km_driven <- suppressWarnings(as.numeric(clean$km_driven))
  values$selling_price_inr <- suppressWarnings(as.numeric(clean$selling_price))
  valid <- with(values, is.finite(year) & year >= 1980 & year <= as.integer(format(Sys.Date(), "%Y")) &
    is.finite(selling_price_inr) & selling_price_inr > 0 & is.finite(km_driven) & km_driven >= 0)
  values <- values[valid, , drop = FALSE]
  values$model <- vapply(seq_len(nrow(values)), function(i) {
    if (values$brand[[i]] == "Unknown") return(values$name[[i]])
    trimws(substring(values$name[[i]], nchar(values$brand[[i]]) + 1L))
  }, character(1))
  if (!nrow(values)) stop("No valid rows remain after the dataset audit.")
  list(vehicles = values, missingness = missingness,
       report = list(raw_rows = nrow(raw), usable_rows = nrow(values),
         exact_duplicates_removed = sum(duplicate), invalid_rows_removed = sum(!valid),
         source_columns = ncol(raw), unknown_brand_rows = sum(values$brand == "Unknown"),
         reference_year = max(values$year), currency = "INR"))
}

dataset_cache <- new.env(parent = emptyenv())
load_dataset <- function() {
  path <- Sys.getenv("VEHICLE_DATA_PATH", file.path(Sys.getenv("VEHICLE_PROJECT_ROOT", "."),
                                                 "data", "raw", "Car details v3.csv"))
  if (!file.exists(path)) return(list(ready = FALSE, message = "Dataset not found. Run scripts/acquire_data.R first."))
  stamp <- paste(normalizePath(path), file.info(path)$mtime, file.info(path)$size)
  if (identical(dataset_cache$stamp, stamp)) return(dataset_cache$value)
  result <- tryCatch({
    raw <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("", "NA"))
    prepared <- prepare_vehicles(raw)
    c(list(ready = TRUE, source = "CarDekho / Kaggle / version 4 / Car details v3.csv"), prepared)
  }, error = function(e) list(ready = FALSE, message = conditionMessage(e)))
  dataset_cache$stamp <- stamp
  dataset_cache$value <- result
  result
}
