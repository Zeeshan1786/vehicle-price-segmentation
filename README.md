# Vehicle Price Prediction and Segmentation

An R-first data science application for estimating used-car listing prices and discovering groups of similar vehicles.

**Current phase: application foundation and exploratory dashboard. No models have been trained.** The dashboard explores real historical CarDekho listings; inference routes return an explicit `MODEL_NOT_TRAINED` response. There are no fabricated estimates, cluster assignments, database connections, or login screens.

## Stack

- Frontend: R Shiny + bslib, responsive dashboard with custom CSS.
- Visualization: seven ggplot2 charts, reactive filters, summary metrics and a searchable DT table.
- Backend: R Plumber REST API; server-side validation and stable JSON errors.
- Data: local CSV files, with raw and processed data excluded from Git.
- Later: saved RDS model/preprocessing artifacts. Training packages are installed separately.

## Run locally

Install R 4.4 or later and optionally RStudio. Open this folder as an RStudio project, or open two terminals in the repository root.

```r
# Once, from the project root
source("scripts/setup.R")
# Acquire the versioned source dataset, then run its audit
source("scripts/acquire_data.R")
source("scripts/audit_data.R")
```

Terminal 1:

```sh
Rscript scripts/run_api.R
```

Terminal 2:

```sh
Rscript scripts/run_frontend.R
```

Open http://127.0.0.1:3838. The API listens on http://127.0.0.1:8000; interactive API documentation is at /__docs__/.

The Dashboard opens first. Filter by manufacturer, fuel, transmission and manufacturing year. Explore price distributions, distance/price relationships, manufacturer price ranges, fuel mix, feature correlations and model-year trends. Inspect source missingness and the cleaning audit, search/sort the table, or export the filtered rows. A compatible CSV can be uploaded for session-only exploration; it is audited by the API without being saved.

The initial local acquisition contains 8,128 source rows and 6,926 rows after whitespace normalization and exact-row deduplication. The source's latest manufacturing year is 2020: these are historical listing prices, not current market valuations. Acquisition metadata and SHA-256 are in data/acquisition_manifest.json. Raw data is excluded from the repository and ZIP; acquire it again after cloning.

In RStudio, use separate R sessions for the two launch scripts because each server blocks its session. Override settings with `Sys.setenv(API_BASE_URL="http://127.0.0.1:8000", API_PORT="8000", SHINY_PORT="3838")`. Launchers bind to loopback by default; no deployment is included.

## Repository map

```text
frontend/                 Shiny UI, server, HTTP client, CSS
backend/                  Plumber routes and service boundary
shared/schema.R           One feature contract for UI and API
data/example/             Synthetic input fixtures; never training data
data/raw/                 Downloaded source CSV, ignored
data/processed/           Future cleaned data and splits, ignored
models/                   Future RDS bundles and model card template
scripts/                  Setup, launch, checks, future training entry points
tests/                    Input contract and model-unavailable checks
docs/                     Architecture, dataset plan, roadmap, API contract
.github/workflows/        R structure checks, without model training
```

## Read next

- [Architecture](docs/ARCHITECTURE.md)
- [Dataset and acquisition plan](docs/DATASET_PLAN.md)
- [API contract](docs/API.md)
- [Implementation roadmap](docs/ROADMAP.md)
- [Data dictionary](data/DATA_DICTIONARY.csv)

## Checks

```sh
Rscript scripts/check.R
```

Checks parse all R sources, exercise validation and model-unavailable behavior, and verify that the real Plumber router can load. CI uses the same command. No training occurs during setup, checks, or app startup.

With the API running and a dataset available, run `Rscript tests/live.R` for HTTP-route checks and Shiny server tests that render all seven charts and exercise a fuel filter. Browser visual inspection is a separate manual check.

The initial scope uses Indian used-car listings and INR. This is a historical exploration dataset, not a live valuation service. See the dataset plan and acquisition manifest for source metadata, units, limitations and the remaining audit tasks before training.
