# Vehicle Price Prediction and Segmentation

An R-first data science application for estimating used-car listing prices and discovering groups of similar vehicles.

**Working dashboard and trained price predictor.** The Price predictor tab uses an R `ranger` random forest selected by training-only grouped cross-validation with dataset-backed inputs and real INR estimates. Segmentation remains untrained. No database or login is required.

## Stack

- Frontend: R Shiny + bslib, responsive dashboard with custom CSS.
- Visualization: seven expandable ggplot2 charts, reactive filters, summary metrics and a paginated DT table.
- Backend: R Plumber REST API; server-side validation and stable JSON errors.
- Data: local CSV files, with raw and processed data excluded from Git.
- Model: versioned RDS trained-model/preprocessing bundle; training and prediction run in R; linear regression is retained as a baseline.

## Price prediction

Open **Price predictor**, choose a manufacturer and model/variant from the dataset, enter the vehicle specifications, then click **Predict price**. Category choices, year/seat options and numeric ranges come from the source dataset. The form never accepts selling price as an input. Manufacturer and the first model token form the model's vehicle-family feature; rare families are pooled, and manufacturer is also a forest feature. Mileage and torque are omitted from this predictor because their source units/formats vary.

The checked-in model uses 5,533 training rows and the unchanged 1,393-row test benchmark, split by matching input profiles with seed 2026. Matching groups do not overlap. Training-only medians handle missing specifications. Five-fold grouped CV within training data compared the linear baseline and six forest settings; minimum pooled CV RMSE selected 500 trees, mtry 11 and node size 3. The selected forest achieved pooled training-only CV R-squared 0.8956.

| Test metric | Random forest | Linear regression | Median-price baseline |
| --- | ---: | ---: | ---: |
| MAE (INR) | 72,503 | 139,369 | 270,623 |
| RMSE (INR) | 133,784 | 245,327 | 496,986 |
| R-squared | 0.9243 | 0.7453 | -0.0452 |

This is a historical listing-price baseline, not a current appraisal. All selected-forest test estimates were positive. Metrics include every original test record without clipping, removing outliers or changing the split. This test set was previously viewed while developing the linear baseline, so these are fixed benchmark results; a new external or future-data evaluation remains necessary. R-squared is not prediction accuracy. See the [model card](models/MODEL_CARD.md) for limitations and preprocessing details.

## Run locally

Install R 4.4 or later and optionally RStudio. Open this folder as an RStudio project, or open two terminals in the repository root.

```r
# Once, from the project root
source("scripts/setup.R")
# Acquire the versioned source dataset, then run its audit
source("scripts/acquire_data.R")
source("scripts/audit_data.R")
# Optional: reproduce training; the validated model is already included
# source("scripts/train_price.R")
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

The Dashboard opens first. Filter by manufacturer, fuel, transmission and manufacturing year. Explore price distributions, distance/price relationships, manufacturer price ranges, fuel mix, feature correlations and model-year trends. Click a chart to expand it; use Close or Escape to return. Inspect source missingness and the cleaning audit, sort/page through the table, or export filtered rows. The dashboard uses only the project's versioned CarDekho dataset.

The initial local acquisition contains 8,128 source rows and 6,926 rows after whitespace normalization and exact-row deduplication. The source's latest manufacturing year is 2020: these are historical listing prices, not current market valuations. Acquisition metadata and SHA-256 are in data/acquisition_manifest.json. Raw data is excluded from the repository and ZIP; acquire it again after cloning.

In RStudio, use separate R sessions for the two launch scripts because each server blocks its session. Override settings with `Sys.setenv(API_BASE_URL="http://127.0.0.1:8000", API_PORT="8000", SHINY_PORT="3838")`. Launchers bind to loopback by default; no deployment is included.

## Repository map

```text
frontend/                 Shiny UI, server, HTTP client, CSS
backend/                  Plumber routes and service boundary
shared/                   Feature validation and model preprocessing/inference
data/example/             Synthetic input fixtures; never training data
data/raw/                 Downloaded source CSV, ignored
data/processed/           Audit, split manifest and test predictions, ignored
models/                   Trained models, selection results, metrics and model card
scripts/                  Setup, launch, audit, training and checks
tests/                    Validation, trained prediction and live app checks
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

Checks parse all R sources, exercise missing-model fallback, trained price inference and validation, and verify that the Plumber router and Shiny app load. CI uses the same command. No training occurs during setup, checks, or app startup. `scripts/train_price.R` reproduces both baselines and the selected forest; `scripts/compare_price_models.R` reruns the full grouped CV experiment into ignored processed files without replacing the deployed model.

With the API running and a dataset available, run `Rscript tests/live.R` for successful price prediction, input options, validation, seven chart renders and a filter change. Browser visual inspection is a separate manual check.

The project uses historical Indian used-car listings and INR. See the dataset plan, acquisition manifest and model card for source metadata, units and limitations. Segmentation and independently verified external-data evaluation remain future work.
