"""Consolidated subscription API router"""
from fastapi import APIRouter, HTTPException, Depends, Request, status
from datetime import datetime

from app.api.dependencies import (
    get_current_user,
    get_subscription_service,
    get_subscription_repository,
)
from app.schemas.subscription import (
    VerifyReceiptRequest,
    SubscriptionStatusResponse,
    ErrorResponse,
)
from app.schemas.webhook import AppleWebhookNotification
from app.services.apple_verifier import (
    verify_apple_receipt,
    extract_subscription_details as extract_apple,
)
from app.services.google_verifier import verify_google_purchase
from app.services.mock_verifier import (
    mock_verify_apple_receipt,
    mock_extract_apple_details,
    mock_verify_google_purchase,
    mock_extract_google_details,
)
from app.services.subscription_service import SubscriptionService
from app.repositories.subscription_repository import SubscriptionRepository
from app.config import settings

router = APIRouter(prefix="/api/v1/subscriptions", tags=["subscriptions"])


@router.post(
    "/verify",
    response_model=SubscriptionStatusResponse,
    responses={
        400: {"model": ErrorResponse},
        401: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def verify_receipt(
    request: VerifyReceiptRequest,
    subscription_service: SubscriptionService = Depends(get_subscription_service),
    user_id: str = Depends(get_current_user),
):
    """
    Verify receipt from Flutter in_app_purchase package.
    Backend verifies receipt with App Store/Play Store server-side.
    """
    try:
        if request.platform == "ios":
            # Use mock or real verifier based on config
            if settings.use_mock_verifiers:
                verification = await mock_verify_apple_receipt(
                    request.receipt_data,
                    settings.apple_shared_secret or "",
                    sandbox=request.sandbox,
                    product_id=request.product_id,
                )
                subscription_data = mock_extract_apple_details(verification)
            else:
                verification = await verify_apple_receipt(
                    request.receipt_data,
                    settings.apple_shared_secret or "",
                    sandbox=request.sandbox,
                )
                subscription_data = extract_apple(verification)
        elif request.platform == "android":
            # Use mock or real verifier based on config
            if settings.use_mock_verifiers:
                mock_result = await mock_verify_google_purchase(
                    package_name=settings.google_package_name,
                    subscription_id=request.product_id,
                    purchase_token=request.receipt_data,
                    credentials_path=settings.google_credentials_path,
                )
                subscription_data = mock_extract_google_details(mock_result, request.product_id)
            else:
                subscription_data = await verify_google_purchase(
                    package_name=settings.google_package_name,
                    subscription_id=request.product_id,
                    purchase_token=request.receipt_data,
                    credentials_path=settings.google_credentials_path,
                )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid platform. Must be 'ios' or 'android'",
            )

        # Parse expiry date
        expiry_date = None
        if subscription_data.get("expiry_date"):
            expiry_date = datetime.fromisoformat(subscription_data["expiry_date"])

        # Store in database using service
        subscription = await subscription_service.create_or_update_subscription(
            user_id=user_id,
            original_transaction_id=subscription_data.get("original_transaction_id")
            or request.original_transaction_id
            or "",
            plan_id=request.product_id,
            receipt_data={
                "receipt_data": request.receipt_data,
                "transaction_id": subscription_data.get("transaction_id"),
                "original_transaction_id": subscription_data.get(
                    "original_transaction_id"
                ),
            },
            platform=request.platform,
            tier=subscription_data.get("tier", "free"),
            is_active=subscription_data.get("is_active", False),
            expiry_date=expiry_date,
        )

        return SubscriptionStatusResponse(
            tier=subscription.tier.value,
            is_active=subscription.is_active,
            expiry_date=subscription.expires_date,
            product_id=subscription.plan_id,
            original_transaction_id=subscription.original_transaction_id,
            verified=True,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}",
        )


@router.get(
    "/users/{user_id}",
    response_model=SubscriptionStatusResponse,
    responses={
        404: {"model": ErrorResponse},
        403: {"model": ErrorResponse},
    },
)
async def get_subscription_status(
    user_id: str,
    subscription_service: SubscriptionService = Depends(get_subscription_service),
    current_user_id: str = Depends(get_current_user),
):
    """
    Get user's current subscription status.
    Returns stored (already verified) subscription from database.
    """
    # Verify user can only access their own subscription
    if user_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot access other user's subscription",
        )

    subscription = await subscription_service.get_subscription_by_user_id(user_id)

    if not subscription:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Subscription not found",
        )

    return SubscriptionStatusResponse(
        tier=subscription.tier.value,
        is_active=subscription.is_active,
        expiry_date=subscription.expires_date,
        product_id=subscription.plan_id,
        original_transaction_id=subscription.original_transaction_id,
        verified=True,
    )


@router.post("/webhook/apple", tags=["webhooks"])
async def handle_apple_webhook(
    request: Request,
    subscription_service: SubscriptionService = Depends(get_subscription_service),
    subscription_repo: SubscriptionRepository = Depends(get_subscription_repository),
):
    """
    Handle Apple App Store Server Notifications.
    Processes events: DID_RENEW, CANCEL, DID_FAIL_TO_RENEW, REFUND, etc.
    Always returns 200 to acknowledge receipt (Apple will retry if needed).
    """
    try:
        # Parse webhook payload
        payload = await request.json()
        notification = AppleWebhookNotification(**payload)

        # Extract user_id from receipt
        unified_receipt = notification.unified_receipt
        latest_receipt_info = unified_receipt.get("latest_receipt_info", [])

        if not latest_receipt_info:
            return {"status": "ok"}  # Acknowledge even if no data

        latest_transaction = latest_receipt_info[-1]
        original_transaction_id = notification.original_transaction_id

        # Find user by original_transaction_id using repository
        existing_subscription = await subscription_repo.get_by_original_transaction_id(
            original_transaction_id
        )

        if not existing_subscription:
            # Can't process webhook without existing subscription
            return {"status": "ok"}

        user_id = existing_subscription.user_id
        product_id = latest_transaction.get(
            "product_id", existing_subscription.plan_id
        )

        # Process notification type
        notification_type = notification.notification_type
        is_active = True
        expires_date = None

        if notification_type in ["DID_RENEW", "INITIAL_BUY"]:
            # Subscription active
            expires_date_ms = latest_transaction.get("expires_date_ms")
            if expires_date_ms:
                expires_date = datetime.fromtimestamp(int(expires_date_ms) / 1000)
            is_active = True
        elif notification_type in ["CANCEL", "REFUND"]:
            # Subscription cancelled
            is_active = False
        elif notification_type == "DID_FAIL_TO_RENEW":
            # Subscription expired
            is_active = False
        elif notification_type == "DID_RECOVER":
            # Subscription recovered
            expires_date_ms = latest_transaction.get("expires_date_ms")
            if expires_date_ms:
                expires_date = datetime.fromtimestamp(int(expires_date_ms) / 1000)
            is_active = True

        # Determine tier
        tier = "free"
        if "premium" in product_id.lower():
            tier = "premium"
        elif "basic" in product_id.lower():
            tier = "basic"

        # Update subscription using service
        await subscription_service.create_or_update_subscription(
            user_id=user_id,
            original_transaction_id=original_transaction_id,
            plan_id=product_id,
            receipt_data=latest_transaction,
            platform="ios",
            tier=tier,
            is_active=is_active,
            expiry_date=expires_date,
        )

        return {"status": "ok"}
    except Exception as e:
        # Always return 200 to Apple (they'll retry if needed)
        # Log error for debugging
        print(f"Error processing Apple webhook: {e}")
        return {"status": "ok"}


@router.post("/webhook/google", tags=["webhooks"])
async def handle_google_webhook(
    request: Request,
    subscription_service: SubscriptionService = Depends(get_subscription_service),
):
    """
    Handle Google Play Real-time Developer Notifications.
    Similar processing for Android subscriptions.
    Always returns 200 to acknowledge receipt.
    """
    try:
        payload = await request.json()
        # TODO: Implement Google Play webhook processing
        # Process Google Play notification
        # Implementation similar to Apple webhook
        return {"status": "ok"}
    except Exception as e:
        print(f"Error processing Google webhook: {e}")
        return {"status": "ok"}
