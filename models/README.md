# Future model artifacts

No trained artifacts are shipped. Both model status fields remain not_trained.

Later bundles should contain the fitted workflow/preprocessor, estimator, feature-schema version, training-data fingerprint, supported categories, model version, reference year and creation timestamp. Prediction must use the saved preprocessing steps.

- price_model.rds
- segmentation_model.rds
- metrics.json
- MODEL_CARD.md

Adding a file does not enable inference in this scaffold. Implement and validate the loader and prediction service during the integration phase. Never load untrusted RDS files uploaded by app users.
