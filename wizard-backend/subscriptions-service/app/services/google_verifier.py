"""Google Play purchase verification service"""
import asyncio
from google.oauth2 import service_account
from googleapiclient.discovery import build
from app.config import settings
from datetime import datetime


async def verify_google_purchase(
    package_name: str,
    subscription_id: str,
    purchase_token: str,
    credentials_path: str
) -> dict:
    """
    Coroutine-based verify purchase with Google Play Developer API
    Uses asyncio.run_in_executor to run sync Google API client
    """
    def _sync_verify():
        credentials = service_account.Credentials.from_service_account_file(
            credentials_path,
            scopes=['https://www.googleapis.com/auth/androidpublisher']
        )
        service = build('androidpublisher', 'v3', credentials=credentials)
        result = service.purchases().subscriptions().get(
            packageName=package_name,
            subscriptionId=subscription_id,
            token=purchase_token
        ).execute()
        return result

    # Run sync Google API client in thread pool executor (coroutine pattern)
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, _sync_verify)
    return extract_subscription_details(result, subscription_id)


def extract_subscription_details(result: dict, product_id: str) -> dict:
    """
    Extract subscription details from Google Play verification response
    
    Returns:
        dict: Subscription details with tier, expiry, etc.
    """
    # Determine tier from product_id
    tier = "free"
    if "premium" in product_id.lower():
        tier = "premium"
    elif "basic" in product_id.lower():
        tier = "basic"

    # Parse expiry date
    expiry_time_millis = result.get("expiryTimeMillis")
    expires_date = None
    if expiry_time_millis:
        expires_date = datetime.fromtimestamp(int(expiry_time_millis) / 1000)

    # Check if active
    auto_renewing = result.get("autoRenewing", False)
    payment_state = result.get("paymentState", 0)
    is_active = auto_renewing or payment_state == 1  # 1 = Payment received

    return {
        "tier": tier,
        "is_active": is_active,
        "expiry_date": expires_date.isoformat() if expires_date else None,
        "product_id": product_id,
        "original_transaction_id": result.get("orderId"),
        "transaction_id": result.get("orderId"),
        "platform": "android",
    }
