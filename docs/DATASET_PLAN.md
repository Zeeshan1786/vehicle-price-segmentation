# Dataset plan

## Proposed source and scope

### Acquisition and modeling status

An R linear-regression price baseline has now been trained. The grouping, train-only preprocessing, exact train/test counts and metrics are documented in models/MODEL_CARD.md. The earlier experiment recommendations below remain guidance for future models; the current fixed baseline does not claim grouped cross-validation or temporal evaluation. Segmentation remains planned.

Version 4 has now been acquired locally from Kaggle's public download endpoint. The selected file contains 8,128 rows and 13 columns. Whitespace-normalized exact-row deduplication leaves 6,926 rows; no additional rows failed the initial price/year/distance guardrails. One manufacturer is unmapped. The latest manufacturing year is 2020. This first audit does not replace near-duplicate grouping, outlier review or leakage-safe train/test splits.

Provider metadata reports "Database: Open Database, Contents: Database Contents". The acquisition manifest records attribution, license links, retrieval timestamp and SHA-256. Raw data stays excluded from Git and source archives. Reproduce acquisition with scripts/acquire_data.R and audit with scripts/audit_data.R. Do not treat the uploader's license metadata as independent verification of every upstream listing's rights.

Source: [Vehicle dataset by Nehal Birla on Kaggle](https://www.kaggle.com/datasets/nehalbirla/vehicle-dataset-from-cardekho), file Car details v3.csv. The selected file has been downloaded and received an initial audit; remaining training preparation is described below.

Initial geographic/currency scope: Indian used cars and INR. Do not combine sources with incompatible currencies, measurement units or listing periods.

## Acquisition gate

1. Inspect the source page and version; confirm license and permitted academic use/redistribution. Do not assume the uploader's license clears all upstream rights.
2. Download the selected CSV manually or through an authenticated provider workflow. No scraping is planned.
3. Record source URL, owner, dataset/file version, retrieval date, license, upstream attribution and SHA-256 in data/raw/acquisition_manifest.json.
4. Record observed row count, column names, year coverage, price currency and measurement units. Counts are deliberately not assumed here.
5. Keep original data in data/raw, excluded from Git. Include only a source manifest if its metadata is safe to share.

## Expected mapping to the application

The candidate is expected to provide name, year, selling_price, km_driven, fuel, seller_type, transmission, owner, engine, max_power and seats. Verify this against the actual downloaded file.

Map selling_price to selling_price_inr; engine to engine_cc; max_power to max_power_bhp. Parse manufacturer and model/variant from name with a reviewed mapping; avoid blindly splitting at the first word because manufacturer names can contain multiple words. See data/DATA_DICTIONARY.csv.

Mileage and torque remain optional exploratory fields. Mileage units may differ between liquid fuels and gaseous fuels, so it must not enter the common schema without unit-specific normalization. Do not infer absent condition, accident, location or service history fields.

The current UI requires complete profiles, while source-data missing values will be handled by fitted preprocessing. Future category support must be aligned with the audited data. Electric vehicles are outside the initial combustion-engine feature contract.

## Data quality

Audit missingness by column and subgroup, invalid/nonpositive target prices, impossible years, negative distances, unit suffixes, numeric parsing failures and rare categorical levels. Quarantine invalid records with reasons and counts rather than silently editing them.

Look for exact duplicate rows and likely repeated listings. Without listing/VIN identifiers, near-duplicate grouping is imperfect; document the fingerprint fields, false merges and remaining leakage risk. Do not remove all expensive cars as outliers. Review plausible extremes and evaluate sensitivity.

Use a fixed reference year derived from source coverage/metadata for any vehicle-age feature. Persist it in the model bundle; changing age with today's date changes the meaning of historical prices.

## Leakage-safe prediction experiment

Reserve approximately 20% of duplicate groups as the untouched test set with seed 2026. When group sizes prevent an exact 80/20 row split, report the realized proportions. Use grouped five-fold cross-validation within the remaining training groups. Apply target stratification only if compatible with keeping groups intact.

Before fitting transformations, split the data. Learn imputation, category grouping, encoding and scaling within each training fold. Do not include target price, arbitrary row IDs or a target-derived cluster label as prediction features. Use a temporal holdout instead if trustworthy listing dates support it.

## Segmentation experiment

Define segmentation as grouping vehicles by attributes, not grouping customers. Exclude selling_price_inr, raw names and arbitrary identifiers from the clustering feature matrix. Start with standardized numeric characteristics (age/year, km, engine, power, seats) for k-means; compare mixed-feature Gower distance with PAM when adding selected categories.

Choose candidate k from 2 through min(8, feasible sample limit), and assess silhouette, minimum cluster size and resampling stability. Sample for Gower/PAM if the audited dataset is too large for pairwise distance memory. Fit preprocessing and clustering on development data; assess assignment/stability on held-out data. Refit on all eligible data only after evaluation, versioning it as a separate final artifact.

Use price only to describe cluster distributions after fitting. Labels such as budget or premium are interpretations and should be assigned only when actual profiles support them.

## Deliverables for the next phase

Acquisition manifest, reproducible cleaning script, audit report, duplicate-group split manifest and an agreed feature contract. Actual model training starts only after these deliverables are reviewed.
