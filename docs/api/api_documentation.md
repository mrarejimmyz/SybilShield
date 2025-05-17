# AptosSybilShield API Documentation

This document provides comprehensive documentation for the AptosSybilShield API endpoints and usage.

## Base URL

```
https://api.aptossybilshield.com
```

For local development:

```
http://localhost:8000
```

## Authentication

All API requests require an API key to be included in the header:

```
api-key: your_api_key_here
```

To obtain an API key, use the `/api/keys` endpoint.

## Endpoints

### API Key Management

#### Create API Key

```
POST /api/keys
```

Request body:
```json
{
  "user_id": "your_user_id",
  "rate_limit": 100
}
```

Response:
```json
{
  "api_key": "ask_1234567890abcdef",
  "user_id": "your_user_id",
  "rate_limit": 100,
  "created_at": "2025-05-16T15:00:00.000Z"
}
```

### Sybil Detection

#### Check Address

```
POST /api/check
```

Request body:
```json
{
  "address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "threshold": 70,
  "include_features": false
}
```

Response:
```json
{
  "address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "is_sybil": false,
  "risk_score": 35,
  "confidence": 85,
  "verification_status": "verified",
  "request_id": "req_1234567890abcdef",
  "timestamp": "2025-05-16T15:00:00.000Z"
}
```

#### Batch Check

```
POST /api/batch-check
```

Request body:
```json
{
  "addresses": [
    "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
  ],
  "threshold": 70
}
```

Response:
```json
{
  "results": {
    "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef": {
      "is_sybil": false,
      "risk_score": 35,
      "confidence": 85,
      "verification_status": "verified"
    },
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890": {
      "is_sybil": true,
      "risk_score": 85,
      "confidence": 90,
      "verification_status": "unverified"
    }
  },
  "request_id": "batch_1234567890abcdef",
  "timestamp": "2025-05-16T15:00:00.000Z"
}
```

#### Get Check Result

```
GET /api/check/{request_id}
```

Response:
```json
{
  "address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "is_sybil": false,
  "risk_score": 35,
  "confidence": 85,
  "verification_status": "verified",
  "timestamp": "2025-05-16T15:00:00.000Z"
}
```

### Identity Verification

#### Start Verification

```
POST /api/verify
```

Request body:
```json
{
  "address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "verification_type": "social_twitter",
  "callback_url": "https://your-app.com/webhook"
}
```

Response:
```json
{
  "verification_id": "ver_1234567890abcdef",
  "address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "verification_type": "social_twitter",
  "status": "pending",
  "instructions": "Post a specific message on Twitter...",
  "expires_at": "2025-05-17T15:00:00.000Z"
}
```

#### Check Verification Status

```
GET /api/verify/{verification_id}
```

Response:
```json
{
  "verification_id": "ver_1234567890abcdef",
  "address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "verification_type": "social_twitter",
  "status": "pending",
  "timestamp": "2025-05-16T15:00:00.000Z"
}
```

#### Complete Verification

```
POST /api/verify/{verification_id}/complete
```

Request body:
```json
{
  "proof": "https://twitter.com/user/status/123456789"
}
```

Response:
```json
{
  "verification_id": "ver_1234567890abcdef",
  "address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "verification_type": "social_twitter",
  "status": "verified",
  "timestamp": "2025-05-16T15:00:00.000Z"
}
```

### Webhooks

#### Subscribe to Webhook

```
POST /api/webhooks
```

Request body:
```json
{
  "event_types": ["verification_complete", "sybil_detected"],
  "url": "https://your-app.com/webhook",
  "secret": "your_webhook_secret"
}
```

Response:
```json
{
  "subscription_id": "sub_1234567890abcdef",
  "event_types": ["verification_complete", "sybil_detected"],
  "url": "https://your-app.com/webhook",
  "created_at": "2025-05-16T15:00:00.000Z"
}
```

#### Unsubscribe from Webhook

```
DELETE /api/webhooks/{subscription_id}
```

Response:
```json
{
  "status": "unsubscribed"
}
```

### Health Check

```
GET /health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2025-05-16T15:00:00.000Z"
}
```

## Webhook Events

When events occur that match your subscribed event types, AptosSybilShield will send a POST request to your webhook URL with the following format:

```json
{
  "event_type": "verification_complete",
  "timestamp": "2025-05-16T15:00:00.000Z",
  "data": {
    "verification_id": "ver_1234567890abcdef",
    "address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "status": "verified"
  }
}
```

## Error Handling

The API uses standard HTTP status codes to indicate the success or failure of requests:

- 200: Success
- 400: Bad request (invalid parameters)
- 401: Unauthorized (invalid API key)
- 404: Not found
- 429: Rate limit exceeded
- 500: Server error

Error responses have the following format:

```json
{
  "detail": "Error message"
}
```

## Rate Limiting

API requests are rate-limited based on the rate_limit specified when creating your API key. The default limit is 100 requests per minute.

If you exceed your rate limit, you will receive a 429 response with a "Rate limit exceeded" error message.

## Best Practices

1. **Cache results**: Store the results of Sybil checks to avoid unnecessary API calls
2. **Use batch checks**: When checking multiple addresses, use the batch endpoint
3. **Handle rate limits**: Implement exponential backoff when rate limits are hit
4. **Secure your API key**: Do not expose your API key in client-side code
5. **Verify webhook signatures**: Use the webhook secret to verify that webhook calls are coming from AptosSybilShield
