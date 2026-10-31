# Model artifacts

- price_model.rds: selected R ranger forest with training-only preprocessing, source-backed form options and evaluation metadata.
- linear_baseline.rds and linear_metrics.json: preserved R stats::lm reference on the same split.
- metrics.json: selected forest's test benchmark and both baselines.
- model_selection.json: training-only grouped CV candidates, scores, selected settings and source fingerprint.
- MODEL_CARD.md: features, preprocessing, metrics and limitations.

The forest bundle omits per-row OOB predictions, calls and in-bag counts. Load only trusted local artifacts. Segmentation remains untrained.

Run scripts/train_price.R to reproduce the selected model and linear reference. Run scripts/compare_price_models.R for the full training-only CV experiment; its candidate outputs stay in ignored data/processed/model_comparison and do not replace the deployed artifact.
