# Implementation roadmap

## 1. Foundation — current scope

Implemented expansion: a real-data exploratory dashboard, dataset acquisition/provenance, initial cleaning audit, CSV preview/upload routes and live chart-rendering checks. Training remains deferred.

R Shiny frontend, Plumber backend, feature validation, explicit untrained responses, example payload, launch scripts, contract checks and documentation. No training or dataset acquisition is part of this phase.

Acceptance: after dependency installation, both processes start; UI connects to health; valid requests report model-not-trained; invalid profiles are rejected; no price/segment is fabricated.

## 2. Dataset audit and reproducibility — next

Verify source rights/version; download and fingerprint the CSV; audit fields, units, parsing, missingness and duplicates. Finalize manufacturer/model mapping and feature categories. Create leakage-safe split manifests. Resolve actual dependencies and commit renv.lock.

Acceptance: one reproducible preparation command writes a quality report and split manifest; raw data remains immutable and ignored.

## 3. Price prediction — later

Install a reviewed training dependency set (candidate packages: tidymodels, ranger, readr, dplyr, janitor and renv). Build a training-median baseline, linear regression, then tuned random forest. Fit preprocessing within grouped cross-validation. Compare validation MAE/RMSE and inspect residuals; use the frozen test set only for the final selected pipeline.

Report MAE and RMSE in INR, R-squared and subgroup errors by fuel/brand/age. Save the fitted preprocessing/model bundle, data fingerprint, reference year and metrics. Avoid promising an accuracy threshold before inspecting the dataset.

## 4. Vehicle segmentation — later

Compare standardized k-means and mixed-type Gower/PAM (candidate packages: cluster and recipes). Select features/k through stability, separation and interpretability. Document nearest-centroid or nearest-medoid assignment for new profiles, with the same saved scaling/encoding as training.

Acceptance: reproducible profiles, sensible minimum group sizes, held-out assignment checks and explicit limitations. No customer segmentation claim is made from vehicle-only records.

## 5. Inference integration — later

Implement trusted artifact loaders and version checks. Replace untrained service responses with validated inference. Add success result cards, formatted INR, segment descriptions, model versions and actionable unknown-category behavior. Expand tests to include saved preprocessing, HTTP success/error behavior and Shiny UI interactions.

Acceptance: a fresh checkout plus documented data/artifacts reproduces the result; held-out metrics and model card accompany it.

## 6. Academic handoff

Prepare an R Markdown/Quarto report with problem statement, data provenance, EDA, preprocessing, model comparisons, segment profiles, limitations and reproducible run instructions.

No database or login work is planned in any phase. Deployment can be planned separately if requested.
