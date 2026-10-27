# Vehicle price linear regression v1

Status: TRAINED. Algorithm: R `stats::lm`, ordinary least squares, raw INR target.
The saved artifact contains only coefficients and preprocessing/aggregate input metadata; no source rows, fitted training values, residuals or QR matrix are included.

## Data and intended use

Historical Indian used-car listing-price exploration using Nehal Birla's CarDekho dataset, version 4, `Car details v3.csv`. Source provenance and SHA-256 appear in `data/acquisition_manifest.json` and `models/metrics.json`. The dashboard audit retains 6,926 of 8,128 rows after whitespace-normalized exact-row deduplication. Latest manufacturing year: 2020.

## Features

Year, distance driven, fuel, seller type, transmission, ownership, engine cc, maximum power bhp, seats and manufacturer/model family. A family combines manufacturer with the first token of the model/variant. Exact variants remain selectable in the form, but their family is used in regression. Families with fewer than ten training rows share an Other coefficient.

Listing price is the target. Mileage and torque are omitted because mixed units and compound source formats need additional cleaning. IDs and price-derived features are excluded.

## Split and preprocessing

Seed 2026; approximately 80/20 split by identical full input profiles, excluding target price. Training: 5,533 rows / 5,357 groups. Test: 1,393 rows / 1,340 groups. Group overlap: zero. Exact matching profiles with different listed prices stay together. Without VIN/listing identifiers, other near-duplicate leakage remains possible; this is not a temporal evaluation.

Numeric imputation medians, category fallbacks and rare-family pooling are learned only from training rows. Nonpositive power is treated as missing. The fitted model has rank 103 and no aliased coefficients. The deployed coefficients are the evaluated training fit; there is no post-evaluation refit on test data.

## Held-out results

| Metric | Linear regression | Training-median baseline |
| --- | ---: | ---: |
| MAE (INR) | 139,369 | 270,623 |
| RMSE (INR) | 245,327 | 496,986 |
| R-squared | 0.7453 | -0.0452 |

MAE is the average absolute price error, not a guaranteed error bound. R-squared is not classification accuracy. Metrics use every raw test prediction without clipping or dropping negative outputs.

## Limitations and UI behavior

88 of 1,393 test predictions were nonpositive (about 6.3%). The API rejects nonpositive estimates with an actionable error instead of displaying an impossible price. The model is a simple baseline and can be poor for rare, old, expensive or unusual combinations. There are no calibrated prediction intervals.

Input categories and ranges come from the source dataset. The API checks manufacturer/model compatibility, warns for pooled families and numeric extrapolation, and applies documented training-mode fallbacks for categorical levels absent from the training split. The frontend shows the evaluated metrics and warnings beside estimates.

Vehicle condition, accident history, region, market date and service history are unavailable. These are historical asking prices, not completed sales or current appraisals. Segmentation remains untrained.

## Reproduce

Run `Rscript scripts/acquire_data.R` if needed, then `Rscript scripts/train_price.R` from the root. The script writes the model, metrics and ignored split/test-output CSVs. Training never runs during API startup.
