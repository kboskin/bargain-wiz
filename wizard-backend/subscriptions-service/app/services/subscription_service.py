"""Subscription business logic service"""
from datetime import datetime
from app.models.subscription import AccountSubscription, SubscriptionReceipt, SubscriptionTier
from app.repositories.subscription_repository import SubscriptionRepository
from app.repositories.receipt_repository import ReceiptRepository


class SubscriptionService:
    """Business logic service for subscriptions"""
    
    def __init__(
        self,
        subscription_repo: SubscriptionRepository,
        receipt_repo: ReceiptRepository,
    ):
        self.subscription_repo = subscription_repo
        self.receipt_repo = receipt_repo
    
    async def create_or_update_subscription(
        self,
        user_id: str,
        original_transaction_id: str,
        plan_id: str,
        receipt_data: dict,
        platform: str,
        tier: str,
        is_active: bool,
        expiry_date: datetime | None,
    ) -> AccountSubscription:
        """
        Create or update subscription in database
        Also stores receipt in subscription_receipts table
        """
        # Check if subscription exists
        existing = await self.subscription_repo.get_by_user_id(user_id)
        
        tier_enum = SubscriptionTier(tier)
        
        if existing:
            # Update existing subscription
            existing.original_transaction_id = original_transaction_id
            existing.plan_id = plan_id
            existing.tier = tier_enum
            existing.is_active = is_active
            existing.expires_date = expiry_date
            existing.platform = platform
            subscription = await self.subscription_repo.update(existing)
        else:
            # Create new subscription
            subscription = AccountSubscription(
                user_id=user_id,
                original_transaction_id=original_transaction_id,
                plan_id=plan_id,
                tier=tier_enum,
                is_active=is_active,
                expires_date=expiry_date,
                platform=platform,
            )
            subscription = await self.subscription_repo.create(subscription)
        
        # Store receipt in subscription_receipts table
        receipt = SubscriptionReceipt(
            user_id=user_id,
            original_transaction_id=original_transaction_id,
            transaction_id=receipt_data.get("transaction_id", original_transaction_id),
            receipt_data=receipt_data,
            plan_id=plan_id,
            purchase_date=datetime.now(),
            expires_date=expiry_date,
            platform=platform,
        )
        await self.receipt_repo.create(receipt)
        
        return subscription
    
    async def get_subscription_by_user_id(
        self, user_id: str
    ) -> AccountSubscription | None:
        """Get user's current subscription"""
        return await self.subscription_repo.get_by_user_id(user_id)
