# Implementation roadmap

## 1. Foundation — current scope

Implemented: real-data exploration, dataset acquisition/provenance, cleaning audit, an R linear regression price model, dataset-based prediction inputs, held-out metrics, validated price inference and live app checks. Segmentation remains deferred.

R Shiny frontend, Plumber backend, validation, example payload, launch scripts, checks and documentation are complete. Missing-model fallbacks remain for unavailable capabilities.

Acceptance: after dependency installation, both processes start; UI connects to health; valid requests report model-not-trained; invalid profiles are rejected; no price/segment is fabricated.

## 2. Dataset audit and reproducibility — next

Verify source rights/version; download and fingerprint the CSV; audit fields, units, parsing, missingness and duplicates. Finalize manufacturer/model mapping and feature categories. Create leakage-safe split manifests. Resolve actual dependencies and commit renv.lock.

Acceptance: one reproducible preparation command writes a quality report and split manifest; raw data remains immutable and ignored.

## 3. Price prediction — baseline implemented; enhancements later

Current implementation uses base R stats::lm, a fixed seed-2026 grouped 80/20 split, training-only preprocessing and a median-price baseline. The evaluated training fit is deployed without refitting on test data. Metrics and limitations are in models/MODEL_CARD.md. Future work below must use a new validation strategy rather than repeatedly selecting models against the existing test set.

Install a reviewed training dependency set (candidate packages: tidymodels, ranger, readr, dplyr, janitor and renv). Build a training-median baseline, linear regression, then tuned random forest. Fit preprocessing within grouped cross-validation. Compare validation MAE/RMSE and inspect residuals; use the frozen test set only for the final selected pipeline.

Report MAE and RMSE in INR, R-squared and subgroup errors by fuel/brand/age. Save the fitted preprocessing/model bundle, data fingerprint, reference year and metrics. Avoid promising an accuracy threshold before inspecting the dataset.

## 4. Vehicle segmentation — later

Compare standardized k-means and mixed-type Gower/PAM (candidate packages: cluster and recipes). Select features/k through stability, separation and interpretability. Document nearest-centroid or nearest-medoid assignment for new profiles, with the same saved scaling/encoding as training.

Acceptance: reproducible profiles, sensible minimum group sizes, held-out assignment checks and explicit limitations. No customer segmentation claim is made from vehicle-only records.

## 5. Inference integration — price complete; segmentation later

The price model loader, version checks, formatted INR result, source-supported inputs and HTTP/Shiny integration tests are implemented. Add segment descriptions and clustering inference only after training and evaluating the segmentation model.

Acceptance: a fresh checkout plus documented data/artifacts reproduces the result; held-out metrics and model card accompany it.

## 6. Academic handoff

Prepare an R Markdown/Quarto report with problem statement, data provenance, EDA, preprocessing, model comparisons, segment profiles, limitations and reproducible run instructions.

No database or login work is planned in any phase. Deployment can be planned separately if requested.
