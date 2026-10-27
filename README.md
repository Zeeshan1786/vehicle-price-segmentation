# Vehicle Price Prediction and Segmentation

An R-first data science application for estimating used-car listing prices and discovering groups of similar vehicles.

**Current phase: project structure. No models have been trained.** The forms and API are wired together; inference routes return an explicit `MODEL_NOT_TRAINED` response. There are no fabricated estimates, cluster assignments, database connections, or login screens.

## Stack

- Frontend: R Shiny + bslib, responsive dashboard with custom CSS.
- Backend: R Plumber REST API; server-side validation and stable JSON errors.
- Data: local CSV files, with raw and processed data excluded from Git.
- Later: saved RDS model/preprocessing artifacts. Training packages are installed separately.

## Run locally

Install R 4.4 or later and optionally RStudio. Open this folder as an RStudio project, or open two terminals in the repository root.

```r
# Once, from the project root
source("scripts/setup.R")
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

The initial scope uses Indian used-car listings and INR. This is a dataset choice, not a live valuation service. Source eligibility, license, row counts, distributions, and units must be verified before acquisition; see the dataset plan.
