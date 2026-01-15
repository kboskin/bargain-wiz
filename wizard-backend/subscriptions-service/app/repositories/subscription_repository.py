"""Abstract subscription repository interface"""
from abc import ABC, abstractmethod
from typing import Optional
from app.models.subscription import AccountSubscription


class SubscriptionRepository(ABC):
    """Abstract interface for subscription data access"""
    
    @abstractmethod
    async def get_by_user_id(self, user_id: str) -> Optional[AccountSubscription]:
        """Get subscription by user ID"""
        pass
    
    @abstractmethod
    async def get_by_original_transaction_id(
        self, original_transaction_id: str
    ) -> Optional[AccountSubscription]:
        """Get subscription by original transaction ID"""
        pass
    
    @abstractmethod
    async def create(self, subscription: AccountSubscription) -> AccountSubscription:
        """Create a new subscription"""
        pass
    
    @abstractmethod
    async def update(self, subscription: AccountSubscription) -> AccountSubscription:
        """Update an existing subscription"""
        pass
