# Integration check: run both launch scripts before invoking this file from the root.
source("frontend/R/client.R")
source("shared/schema.R")
health <- api_request("/health")
stopifnot(health$ok, identical(health$body$status, "ok"))
dataset <- api_request("/data/vehicles")
stopifnot(dataset$ok, isTRUE(dataset$body$ready), is.data.frame(dataset$body$vehicles),
          nrow(dataset$body$vehicles) > 0L)
response <- api_request("/predict", vehicle_example())
stopifnot(response$status == 503L, identical(response$body$code, "MODEL_NOT_TRAINED"))
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
message("Live HTTP routes and all seven dashboard plots passed integration checks.")
