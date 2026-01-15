"""Mock verifiers for development and testing"""
from datetime import datetime, timedelta
from typing import Optional


async def mock_verify_apple_receipt(
    receipt_data: str,
    shared_secret: str,
    sandbox: bool = False,
    product_id: Optional[str] = None,
) -> dict:
    """
    Mock Apple receipt verification for development.
    Returns fake verification response based on product_id.
    """
    # Extract product_id from receipt_data if it's a mock format
    # Format: "mock:{product_id}" or just use the provided product_id
    if product_id is None:
        if receipt_data.startswith("mock:"):
            product_id = receipt_data.split(":")[1] if ":" in receipt_data else "com.bargain.wiz.basic"
        else:
            product_id = "com.bargain.wiz.basic"  # Default to basic
    
    # Determine tier from product_id
    tier = "free"
    if "premium" in product_id.lower():
        tier = "premium"
    elif "basic" in product_id.lower():
        tier = "basic"
    
    # Generate fake transaction IDs
    import random
    transaction_id = f"mock_trans_{random.randint(1000000, 9999999)}"
    original_transaction_id = f"mock_original_{random.randint(1000000, 9999999)}"
    
    # Set expiry date to 30 days from now
    expires_date = datetime.now() + timedelta(days=30)
    expires_date_ms = int(expires_date.timestamp() * 1000)
    
    # Mock Apple verification response format
    return {
        "status": 0,  # Success
        "environment": "Sandbox" if sandbox else "Production",
        "receipt": {
            "receipt_type": "ProductionSandbox",
            "bundle_id": "com.bargain.wiz",
            "application_version": "1.0",
        },
        "latest_receipt_info": [
            {
                "product_id": product_id,
                "transaction_id": transaction_id,
                "original_transaction_id": original_transaction_id,
                "purchase_date_ms": str(int((datetime.now() - timedelta(days=1)).timestamp() * 1000)),
                "expires_date_ms": str(expires_date_ms),
                "is_trial_period": "false",
                "is_in_intro_offer_period": "false",
            }
        ],
        "pending_renewal_info": [
            {
                "expiration_intent": "1",
                "auto_renew_status": "1",
                "product_id": product_id,
            }
        ],
    }


async def mock_verify_google_purchase(
    package_name: str,
    subscription_id: str,
    purchase_token: str,
    credentials_path: str,
) -> dict:
    """
    Mock Google Play purchase verification for development.
    Returns fake verification response based on subscription_id.
    """
    # Extract product_id from purchase_token if it's a mock format
    # Format: "mock:{product_id}" or use subscription_id
    product_id = subscription_id
    if purchase_token.startswith("mock:"):
        product_id = purchase_token.split(":")[1] if ":" in purchase_token else subscription_id
    
    # Determine tier from product_id
    tier = "free"
    if "premium" in product_id.lower():
        tier = "premium"
    elif "basic" in product_id.lower():
        tier = "basic"
    
    # Generate fake order ID
    import random
    order_id = f"mock_order_{random.randint(1000000, 9999999)}"
    
    # Set expiry date to 30 days from now
    expires_date = datetime.now() + timedelta(days=30)
    expiry_time_millis = int(expires_date.timestamp() * 1000)
    
    # Mock Google Play verification response format
    return {
        "kind": "androidpublisher#subscriptionPurchase",
        "orderId": order_id,
        "packageName": package_name,
        "productId": product_id,
        "purchaseTimeMillis": str(int((datetime.now() - timedelta(days=1)).timestamp() * 1000)),
        "expiryTimeMillis": str(expiry_time_millis),
        "autoRenewing": True,
        "paymentState": 1,  # Payment received
        "countryCode": "US",
        "priceCurrencyCode": "USD",
        "priceAmountMicros": "9990000",  # $9.99
    }


def mock_extract_apple_details(verification: dict) -> dict:
    """Extract subscription details from mock Apple verification response"""
    latest_receipt_info = verification.get("latest_receipt_info", [])
    if not latest_receipt_info:
        raise ValueError("No receipt info found in verification response")
    
    latest_transaction = latest_receipt_info[-1]
    product_id = latest_transaction.get("product_id", "")
    
    tier = "free"
    if "premium" in product_id.lower():
        tier = "premium"
    elif "basic" in product_id.lower():
        tier = "basic"
    
    expires_date_ms = latest_transaction.get("expires_date_ms")
    expires_date = None
    if expires_date_ms:
        expires_date = datetime.fromtimestamp(int(expires_date_ms) / 1000)
    
    return {
        "tier": tier,
        "is_active": True,
        "expiry_date": expires_date.isoformat() if expires_date else None,
        "product_id": product_id,
        "original_transaction_id": latest_transaction.get("original_transaction_id"),
        "transaction_id": latest_transaction.get("transaction_id"),
        "platform": "ios",
    }


def mock_extract_google_details(result: dict, product_id: str) -> dict:
    """Extract subscription details from mock Google Play verification response"""
    tier = "free"
    if "premium" in product_id.lower():
        tier = "premium"
    elif "basic" in product_id.lower():
        tier = "basic"
    
    expiry_time_millis = result.get("expiryTimeMillis")
    expires_date = None
    if expiry_time_millis:
        expires_date = datetime.fromtimestamp(int(expiry_time_millis) / 1000)
    
    auto_renewing = result.get("autoRenewing", False)
    payment_state = result.get("paymentState", 0)
    is_active = auto_renewing or payment_state == 1
    
    return {
        "tier": tier,
        "is_active": is_active,
        "expiry_date": expires_date.isoformat() if expires_date else None,
        "product_id": product_id,
        "original_transaction_id": result.get("orderId"),
        "transaction_id": result.get("orderId"),
        "platform": "android",
    }
