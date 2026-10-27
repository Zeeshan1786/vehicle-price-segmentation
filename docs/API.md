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
