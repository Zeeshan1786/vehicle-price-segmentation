# API contract v1.0

Base URL: http://127.0.0.1:8000. Responses use JSON with scalar unboxing.
No authentication is required. This is intended for loopback use.

| Method | Route | Current behavior |
| --- | --- | --- |
| GET | /health | 200: process status plus model readiness |
| GET | /schema | 200: feature contract, INR currency and synthetic example |
| GET | /models/status | 200: both models not_trained, inference_enabled false |
| GET | /segments | 503 MODEL_NOT_TRAINED |
| POST | /predict | validates profile, then 503 MODEL_NOT_TRAINED |
| POST | /segment | validates profile, then 503 MODEL_NOT_TRAINED |
| GET | /data/status | source availability and full-dataset audit summary |
| GET | /data/vehicles | audited listing records plus source and quality metadata |
| POST | /data/preview | audit a text/csv body in memory; return records and quality metadata |

Send Content-Type: application/json to POST routes. See data/example/vehicle_request.json for all required fields. No target price is accepted as an inference feature. Additional fields are rejected. Feature ranges are broad application guardrails, not a claim about observed source support.

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
- 503 MODEL_NOT_TRAINED: valid request but model capability is unavailable.
- 503 DATASET_NOT_READY: source CSV is absent or fails the audit.
- 422 INVALID_DATASET: uploaded CSV has an invalid schema or no eligible rows.
- 413 CSV_SIZE_LIMIT: uploaded CSV exceeds 15 MB.

The dataset routes are descriptive only and fit no models. Uploaded CSVs must use the CarDekho v3 source columns, including name, year, selling_price, km_driven, fuel, seller_type, transmission, owner, engine, max_power and seats. The frontend holds the returned records in the current Shiny session. The API does not persist uploads or replace the repository dataset. VEHICLE_DATA_PATH can point to a different server-side source CSV; use an absolute path.

Try a request from the repository root:

```sh
curl -X POST http://127.0.0.1:8000/predict -H "Content-Type: application/json" --data-binary @data/example/vehicle_request.json
```

On Windows PowerShell use curl.exe for the same syntax.

## Planned success contracts (not implemented)

Predict: 200 with predicted_price_inr, currency, model_version, schema_version and warnings. Add a prediction interval only after implementing and evaluating a calibration method; do not label a point estimate as confidence.

Segment: 200 with segment_id, descriptive segment label, model_version and schema_version.
Segments: 200 with versioned feature profiles and source population counts.
The frontend success-result rendering is a future integration task alongside these responses.
