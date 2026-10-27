if (!file.exists("shared/schema.R")) stop("Run audit from the repository root.")
source("backend/R/data.R")
dataset <- load_dataset()
if (!dataset$ready) stop(dataset$message)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(report = dataset$report, missingness = dataset$missingness),
  "data/processed/data_quality_report.json", auto_unbox = TRUE, pretty = TRUE)
print(dataset$report)
message("Audit complete. No preprocessing was fitted and no models were trained.")
