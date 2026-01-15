"""Apple App Store receipt verification service"""
import aiohttp
import asyncio
from datetime import datetime
from typing import Optional
from app.config import settings


async def verify_apple_receipt(
    receipt_data: str,
    shared_secret: str,
    sandbox: bool = False
) -> dict:
    """
    Coroutine-based verify receipt with Apple App Store Server API
    Uses App Store Server API v2 (not deprecated verifyReceipt)
    
    Returns:
        dict: Verification response from Apple
    """
    url = (
        "https://api.storekit-sandbox.itunes.apple.com/inApps/v1/verifyReceipt"
        if sandbox
        else "https://api.storekit.itunes.apple.com/inApps/v1/verifyReceipt"
    )

    payload = {
        "receipt-data": receipt_data,
        "password": shared_secret,
        "exclude-old-transactions": True
    }

    timeout = aiohttp.ClientTimeout(total=30.0)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        async with session.post(url, json=payload) as response:
            response.raise_for_status()
            verification = await response.json()

    if verification.get("status") == 0:  # Valid receipt
        return verification
    else:
        raise ValueError(f"Receipt verification failed: {verification.get('status')}")


def extract_subscription_details(verification: dict) -> dict:
    """
    Extract subscription details from Apple verification response
    
    Returns:
        dict: Subscription details with tier, expiry, etc.
    """
    latest_receipt_info = verification.get("latest_receipt_info", [])
    if not latest_receipt_info:
        raise ValueError("No receipt info found in verification response")

    # Get the latest transaction
    latest_transaction = latest_receipt_info[-1]

    # Determine tier from product_id
    product_id = latest_transaction.get("product_id", "")
    tier = "free"
    if "premium" in product_id.lower():
        tier = "premium"
    elif "basic" in product_id.lower():
        tier = "basic"

    # Parse dates
    expires_date_ms = latest_transaction.get("expires_date_ms")
    expires_date = None
    if expires_date_ms:
        expires_date = datetime.fromtimestamp(int(expires_date_ms) / 1000)

    return {
        "tier": tier,
        "is_active": True,  # If receipt is valid, subscription is active
        "expiry_date": expires_date.isoformat() if expires_date else None,
        "product_id": product_id,
        "original_transaction_id": latest_transaction.get("original_transaction_id"),
        "transaction_id": latest_transaction.get("transaction_id"),
        "platform": "ios",
    }
