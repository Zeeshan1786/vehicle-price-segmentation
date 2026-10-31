# Vehicle price random forest v1

Status: TRAINED. Selected model: R ranger random forest. The original R stats::lm baseline is retained in linear_baseline.rds and can be reproduced with scripts/train_linear.R.

## Data and intended use

Historical Indian used-car asking-price exploration using Nehal Birla's CarDekho dataset, version 4, Car details v3.csv. Source attribution, reported license and SHA-256 appear in data/acquisition_manifest.json and models/metrics.json. Whitespace-normalized exact-row deduplication retains 6,926 of 8,128 records. Latest manufacturing year: 2020. Prices are INR asking prices, not sale prices or current appraisals.

## Features and preprocessing

Year, distance, engine cc, maximum power bhp, seats, fuel, seller type, transmission, ownership, manufacturer and manufacturer/model family: 11 predictors. Selling price is the target. Exact variants remain selectable; the first model token defines the family. Manufacturer and family groups with fewer than three analysis/training records are pooled. Numeric medians and categorical fallbacks are learned only on each analysis fold or final training partition. Nonpositive power is treated as missing. Mileage and torque remain omitted because mixed units and compound source formats need further work.

## Split and selection

The original seed-2026 split is unchanged: 5,533 training rows / 5,357 matching-profile groups, and 1,393 test rows / 1,340 groups. Group overlap is zero. Profiles use every available inference field, excluding target price. Without VIN/listing IDs, other near-duplicate leakage remains possible.

Five-fold grouped cross-validation within training data (fold seed 2027) compared the linear baseline and six random forests: mtry 4/8/11 crossed with min.node.size 3/5, each with 500 trees. Preprocessing was refitted inside each fold. Minimum pooled out-of-fold RMSE selected mtry 11 and node size 3; CV MAE was INR 78,639, RMSE INR 170,534 and R-squared 0.8956. The selected settings were recorded before evaluating the unchanged test set.

Final forest seed: 2034; 500 trees; variance splits; ordered handling of unordered factors; 2 threads. It was fitted on training rows only and was not refitted on test labels. Default training reproduces these recorded settings; compare_price_models.R reproduces selection separately. The model-selection file is tied to the source-data SHA-256.

## Unchanged test benchmark

| Metric | Random forest | Linear baseline | Median baseline |
| --- | ---: | ---: | ---: |
| MAE (INR) | 72,503 | 139,369 | 270,623 |
| RMSE (INR) | 133,784 | 245,327 | 496,986 |
| R-squared | 0.9243 | 0.7453 | -0.0452 |

All 1,393 original test rows are included, with no output clipping or outlier removal. All forest estimates were positive; the linear baseline produced 88 nonpositive estimates. R-squared is explained variation, not classification accuracy. MAE is a population average and not an error bound for an individual vehicle. No calibrated prediction intervals are provided. OOB training diagnostics are distinct from CV and held-out scores.

## Evaluation limits

The test benchmark had already been viewed for the linear model before the improvement request. Model settings were selected using training-only CV, but the reported test result is a reused development benchmark, not a fresh blind audit. A new external dataset, later-period listings or separately reserved future data is needed for independently verified performance. Source-specific duplicates, historical sampling, sparse luxury vehicles and missing condition/accident/service/region information limit generalization. Forest predictions also do not extrapolate numeric trends beyond learned splits.

## Artifacts and API

price_model.rds contains fitted trees and preprocessing/aggregate form metadata. Per-row OOB predictions, calls and in-bag counts are excluded. The loader accepts validated trusted local forest or legacy linear bundles. Inputs are checked against dataset categories, numeric ranges and manufacturer/model compatibility. Pooled groups, fallback categories and numeric extrapolation produce warnings. Segmentation remains untrained.

Reproduce: acquire source if needed, run scripts/setup.R, then scripts/train_price.R. Training never runs at API startup. metrics.json, linear_metrics.json and model_selection.json preserve the comparison and selection evidence; row-level splits and predictions remain ignored in data/processed.
