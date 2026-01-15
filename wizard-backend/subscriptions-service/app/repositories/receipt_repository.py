"""Abstract receipt repository interface"""
from abc import ABC, abstractmethod
from typing import Optional, List
from app.models.subscription import SubscriptionReceipt


class ReceiptRepository(ABC):
    """Abstract interface for receipt data access"""
    
    @abstractmethod
    async def create(self, receipt: SubscriptionReceipt) -> SubscriptionReceipt:
        """Create a new receipt"""
        pass
    
    @abstractmethod
    async def get_by_user_id(self, user_id: str) -> List[SubscriptionReceipt]:
        """Get all receipts for a user"""
        pass
    
    @abstractmethod
    async def get_by_transaction_id(
        self, transaction_id: str
    ) -> Optional[SubscriptionReceipt]:
        """Get receipt by transaction ID"""
        pass
