# API contract v1.1

Base URL: http://127.0.0.1:8000. Responses use JSON with scalar unboxing.
No authentication is required. This is intended for loopback use.

| Method | Route | Current behavior |
| --- | --- | --- |
| GET | /health | 200: process status plus model readiness |
| GET | /schema | 200: feature contract, INR currency and synthetic example |
| GET | /models/status | 200: price trained, segmentation not_trained, price model version |
| GET | /predictor/options | dataset-derived input categories/ranges, example and held-out metrics |
| GET | /segments | 503 MODEL_NOT_TRAINED |
| POST | /predict | validates profile and manufacturer/model compatibility, returns trained INR estimate |
| POST | /segment | validates profile, then 503 MODEL_NOT_TRAINED |
| GET | /data/status | source availability and full-dataset audit summary |
| GET | /data/vehicles | audited listing records plus source and quality metadata |
| POST | /data/preview | audit a text/csv body in memory; return records and quality metadata |

Send Content-Type: application/json to inference POST routes. See data/example/vehicle_request.json for all required fields. No target price is accepted as an inference feature. Additional fields are rejected. The trained predictor's allowed choices and ranges come from /predictor/options. Unknown model/brand pairs are rejected; unseen training categories can use documented fallbacks with warnings.

Error body:

```json
{
  "status": "error",
  "code": "MODEL_NOT_TRAINED",
  "message": "Price prediction will be available after model training.",
  "details": []
}
```

- 400 INVALID_JSON: invalid JSON, JSON null or empty body.
- 422 VALIDATION_ERROR: missing/unknown fields, non-scalar values, wrong types, unsupported categories or ranges.
- 422 UNSUPPORTED_ESTIMATE: this price model produced a nonpositive/nonfinite estimate for the submitted combination; no price is returned.
- 503 MODEL_NOT_TRAINED: valid request but model capability is unavailable.
- 503 DATASET_NOT_READY: source CSV is absent or fails the audit.
- 422 INVALID_DATASET: uploaded CSV has an invalid schema or no eligible rows.
- 413 CSV_SIZE_LIMIT: uploaded CSV exceeds 15 MB.

The dataset routes are descriptive only and fit no models. The standalone /data/preview API accepts CarDekho v3 source columns and returns an audit without persistence; uploads are not offered in the dashboard. VEHICLE_DATA_PATH can point to a different server-side source CSV; use an absolute path. The model is trained separately and never refits on an uploaded preview.

Try a request from the repository root:

```sh
curl -X POST http://127.0.0.1:8000/predict -H "Content-Type: application/json" --data-binary @data/example/vehicle_request.json
```

On Windows PowerShell use curl.exe for the same syntax.

## Prediction success response

Predict: 200 with status=ok, predicted_price_inr, currency=INR, model_version, algorithm, schema_version, test_metrics and warnings. The point estimate has no confidence/prediction interval. Metrics describe the held-out test population; they are not an error bound for one submitted vehicle.

Segmentation remains untrained and returns 503 MODEL_NOT_TRAINED. Price routes return the same fallback if the model artifact is absent or fails validation. PRICE_MODEL_PATH can select a trusted local artifact; the API does not accept uploaded model files.
