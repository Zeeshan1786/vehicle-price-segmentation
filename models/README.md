# Model artifacts

price_model.rds contains a trained R linear regression's coefficients, fitted preprocessing metadata, dataset-derived form options and held-out metrics. The loader checks its artifact version, formula, finite coefficients and a positive example prediction before marking price inference ready. Segmentation remains not_trained.

The bundle includes the source fingerprint, model version, reference year and creation timestamp. Prediction reuses training preprocessing. Per-row training data, the lm QR matrix and residuals are omitted from the shipped bundle.

- price_model.rds
- segmentation_model.rds (future)
- metrics.json
- MODEL_CARD.md

Reproduce with Rscript scripts/train_price.R after acquiring the source dataset. See MODEL_CARD.md and metrics.json. Never load untrusted RDS files; only the trusted local model artifact is accepted.
