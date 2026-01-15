# Mock Mode for Development

This document explains how to use mock data for development and testing without requiring real Apple/Google credentials.

## Enabling Mock Mode

**Important**: Mock mode must be explicitly enabled. Setting `DEBUG=true` will use **sandbox** (real APIs), not mocks.

Set the `USE_MOCK_VERIFIERS` environment variable to `true`:

```bash
export USE_MOCK_VERIFIERS=true
```

Or add it to your `.env` file:

```
USE_MOCK_VERIFIERS=true
```

## How It Works

When mock mode is enabled:
- The existing `/api/v1/subscriptions/verify` endpoint returns mock responses
- Receipt verification is bypassed
- Mock verifiers return fake subscription data based on the product ID
- No real API calls to Apple/Google servers
- Perfect for local development and testing

**When mock mode is disabled** (default):
- `DEBUG=true` uses **sandbox** APIs (real Apple/Google sandbox environments)
- `DEBUG=false` uses **production** APIs

## Using Mock Receipts

### iOS Mock Receipt Format

When calling `/api/v1/subscriptions/verify` with `USE_MOCK_VERIFIERS=true`, use one of these formats for `receipt_data`:

1. **Simple format**: Just send the product ID
   ```json
   {
     "receipt_data": "com.bargain.wiz.basic",
     "platform": "ios",
     "product_id": "com.bargain.wiz.basic",
     "user_id": "user_123",
     "sandbox": false
   }
   ```

2. **Explicit mock format**: Prefix with `mock:`
   ```json
   {
     "receipt_data": "mock:com.bargain.wiz.premium",
     "platform": "ios",
     "product_id": "com.bargain.wiz.premium",
     "user_id": "user_123",
     "sandbox": false
   }
   ```

### Android Mock Receipt Format

For Android, use the same format for `receipt_data` (which maps to `purchase_token`):

```json
{
  "receipt_data": "mock:com.bargain.wiz.basic",
  "platform": "android",
  "product_id": "com.bargain.wiz.basic",
  "user_id": "user_123",
  "sandbox": false
}
```

## Product IDs

The mock system recognizes these product IDs and assigns tiers:

- `com.bargain.wiz.basic` → `basic` tier
- `com.bargain.wiz.premium` → `premium` tier
- Any other ID → `free` tier

## Example Flow

1. **Enable mock mode**:
   ```bash
   export USE_MOCK_VERIFIERS=true
   ```

2. **Start the service**:
   ```bash
   uv run uvicorn app.main:app --reload
   ```

3. **Verify a mock receipt** (uses existing `/verify` endpoint):
   ```bash
   curl -X POST "http://localhost:8000/api/v1/subscriptions/verify" \
     -H "Authorization: Bearer <your_firebase_token>" \
     -H "Content-Type: application/json" \
     -d '{
       "receipt_data": "mock:com.bargain.wiz.basic",
       "platform": "ios",
       "product_id": "com.bargain.wiz.basic",
       "user_id": "user_123",
       "sandbox": false
     }'
   ```

4. **Check subscription status**:
   ```bash
   curl "http://localhost:8000/api/v1/subscriptions/users/user_123" \
     -H "Authorization: Bearer <your_firebase_token>"
   ```

## Flutter App Integration

In your Flutter app, when in development mode with mock backend, you can send mock receipt data:

```dart
// In subscription_sync_service.dart or test code
final mockReceipt = 'mock:${productId}'; // e.g., 'mock:com.bargain.wiz.premium'
```

The backend will recognize this format when `USE_MOCK_VERIFIERS=true` and return mock subscription data.

## Notes

- Mock subscriptions expire 30 days from creation
- Transaction IDs are randomly generated
- All mock subscriptions are marked as active by default
- **Mock mode is separate from debug mode**: `DEBUG=true` uses sandbox APIs, not mocks
- To use mocks, you must explicitly set `USE_MOCK_VERIFIERS=true`
