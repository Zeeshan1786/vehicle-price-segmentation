if (!file.exists("shared/schema.R")) stop("Run acquisition from the repository root.")
url <- "https://www.kaggle.com/api/v1/datasets/download/nehalbirla/vehicle-dataset-from-cardekho?datasetVersionNumber=4"
metadata_url <- "https://www.kaggle.com/api/v1/datasets/view/nehalbirla/vehicle-dataset-from-cardekho"
destination <- file.path("data", "raw", "Car details v3.csv")
if (file.exists(destination)) stop("Source already exists. Preserve its manifest and original bytes; acquisition will not overwrite it.")
dir.create(file.path("data", "raw"), recursive = TRUE, showWarnings = FALSE)
metadata <- httr2::resp_body_json(httr2::req_perform(httr2::request(metadata_url)))
if (!identical(metadata$licenseName, "Database: Open Database, Contents: Database Contents")) {
  stop("Source license metadata changed. Review the source before downloading.")
}
archive <- tempfile(fileext = ".zip")
download.file(url, archive, mode = "wb", method = "libcurl")
entries <- unzip(archive, list = TRUE)$Name
selected <- entries[entries == "Car details v3.csv"]
if (length(selected) != 1L) stop("Expected source CSV is absent from the provider archive.")
unzip(archive, files = selected, exdir = file.path("data", "raw"))
source("backend/R/data.R")
dataset <- load_dataset()
if (!dataset$ready) stop(dataset$message)
manifest <- list(source_url = "https://www.kaggle.com/datasets/nehalbirla/vehicle-dataset-from-cardekho",
  download_url = url, dataset_version = 4L, source_file = "Car details v3.csv",
  retrieved_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  license = metadata$licenseName, attribution = "Nehal Birla; upstream listing context: CarDekho",
  license_url = "https://opendatacommons.org/licenses/odbl/1-0/",
  contents_license_url = "https://opendatacommons.org/licenses/dbcl/1-0/",
  sha256 = paste0(openssl::sha256(file(destination, "rb"))),
  audit = dataset$report,
  note = "Historical listing prices; not completed sale prices. Raw data remains excluded from Git.")
jsonlite::write_json(manifest, "data/acquisition_manifest.json", auto_unbox = TRUE, pretty = TRUE)
message("Dataset acquired and audited. No models have been trained.")
