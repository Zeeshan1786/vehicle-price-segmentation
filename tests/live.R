# Integration check: run both launch scripts before invoking this file from the root.
source("frontend/R/client.R")
source("shared/schema.R")
health <- api_request("/health")
stopifnot(health$ok, identical(health$body$status, "ok"))
dataset <- api_request("/data/vehicles")
stopifnot(dataset$ok, isTRUE(dataset$body$ready), is.data.frame(dataset$body$vehicles),
          nrow(dataset$body$vehicles) > 0L)
response <- api_request("/predict", vehicle_example())
stopifnot(response$status == 200L, response$body$predicted_price_inr > 0,
          identical(response$body$model_version, "linear-regression-v1"))
options <- api_request("/predictor/options")
stopifnot(options$ok, "Maruti" %in% options$body$fields$brand$choices,
          "Swift Dzire VDI" %in% options$body$models_by_brand$Maruti)
stopifnot(api_request("/segment", vehicle_example())$status == 503L)
invalid <- vehicle_example()
invalid$km_driven <- -100
stopifnot(api_request("/predict", invalid)$status == 422L)
bad_csv <- api_request("/data/preview", charToRaw("wrong,columns\n1,2"), content_type = "csv")
stopifnot(bad_csv$status == 422L, identical(bad_csv$body$code, "INVALID_DATASET"))
source("tests/data.R")
csv <- paste(capture.output(write.csv(raw, row.names = FALSE, na = "")), collapse = "\n")
uploaded <- api_request("/data/preview", charToRaw(csv), content_type = "csv")
stopifnot(uploaded$ok, isTRUE(uploaded$body$ready), nrow(uploaded$body$vehicles) == 2L)
stopifnot(api_request("/data/status")$body$report$usable_rows == dataset$body$report$usable_rows)
app <- source("frontend/app.R", local = new.env(parent = globalenv()), chdir = TRUE)$value
shiny::testServer(app$serverFuncSource(), {
  session$setInputs(dash_brand = "__all__", dash_fuel = "__all__", dash_transmission = "__all__",
                   dash_year = c(1980, as.integer(format(Sys.Date(), "%Y"))), dash_log = TRUE)
  session$flushReact()
  stopifnot(grepl("Swift Dzire VDI", output$predictor_form$html, fixed = TRUE))
  session$setInputs(brand = "Maruti", model = "Swift Dzire VDI", year = "2018",
    km_driven = 45000, fuel = "Diesel", seller_type = "Individual", transmission = "Manual",
    owner = "First Owner", engine_cc = 1248, max_power_bhp = 74, seats = "5", predict = 1)
  session$flushReact()
  stopifnot(grepl("ESTIMATED HISTORICAL LISTING PRICE", output$result$html, fixed = TRUE),
            grepl("INR", output$result$html, fixed = TRUE))
  stopifnot(nchar(output$dash_kpis) > 0L)
  all_kpis <- output$dash_kpis
  for (name in c("dash_scatter", "dash_hist", "dash_brands", "dash_fuel_plot",
                 "dash_year_plot", "dash_correlation", "dash_missing")) {
    plot <- output[[name]]
    stopifnot(is.list(plot), !is.null(plot$src))
  }
  session$setInputs(dash_fuel = "Petrol")
  session$flushReact()
  stopifnot(nchar(output$dash_kpis) > 0L)
  stopifnot(!identical(all_kpis, output$dash_kpis))
})
message("Live price prediction, dataset-backed inputs, HTTP routes and all seven dashboard plots passed.")
