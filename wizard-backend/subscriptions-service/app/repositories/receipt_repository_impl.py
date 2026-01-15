"""SQLAlchemy implementation of receipt repository"""
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.subscription import SubscriptionReceipt
from app.repositories.receipt_repository import ReceiptRepository


class ReceiptRepositoryImpl(ReceiptRepository):
    """SQLAlchemy implementation of ReceiptRepository"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create(self, receipt: SubscriptionReceipt) -> SubscriptionReceipt:
        """Create a new receipt"""
        self.db.add(receipt)
        await self.db.commit()
        await self.db.refresh(receipt)
        return receipt
    
    async def get_by_user_id(self, user_id: str) -> List[SubscriptionReceipt]:
        """Get all receipts for a user"""
        stmt = select(SubscriptionReceipt).where(
            SubscriptionReceipt.user_id == user_id
        ).order_by(SubscriptionReceipt.created_at.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())
    
    async def get_by_transaction_id(
        self, transaction_id: str
    ) -> Optional[SubscriptionReceipt]:
        """Get receipt by transaction ID"""
        stmt = select(SubscriptionReceipt).where(
            SubscriptionReceipt.transaction_id == transaction_id
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
