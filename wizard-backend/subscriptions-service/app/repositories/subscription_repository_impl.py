"""SQLAlchemy implementation of subscription repository"""
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.subscription import AccountSubscription
from app.repositories.subscription_repository import SubscriptionRepository


class SubscriptionRepositoryImpl(SubscriptionRepository):
    """SQLAlchemy implementation of SubscriptionRepository"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_by_user_id(
        self, user_id: str
    ) -> Optional[AccountSubscription]:
        """Get subscription by user ID"""
        stmt = select(AccountSubscription).where(
            AccountSubscription.user_id == user_id
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def get_by_original_transaction_id(
        self, original_transaction_id: str
    ) -> Optional[AccountSubscription]:
        """Get subscription by original transaction ID"""
        stmt = select(AccountSubscription).where(
            AccountSubscription.original_transaction_id == original_transaction_id
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def create(
        self, subscription: AccountSubscription
    ) -> AccountSubscription:
        """Create a new subscription"""
        self.db.add(subscription)
        await self.db.commit()
        await self.db.refresh(subscription)
        return subscription
    
    async def update(
        self, subscription: AccountSubscription
    ) -> AccountSubscription:
        """Update an existing subscription"""
        await self.db.commit()
        await self.db.refresh(subscription)
        return subscription
