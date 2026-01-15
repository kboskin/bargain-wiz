"""Base repository interface with common CRUD operations"""
from abc import ABC, abstractmethod
from typing import Generic, TypeVar, Optional
from sqlalchemy.ext.asyncio import AsyncSession

T = TypeVar("T")


class BaseRepository(ABC, Generic[T]):
    """Generic base repository interface"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    @abstractmethod
    async def create(self, entity: T) -> T:
        """Create a new entity"""
        pass
    
    @abstractmethod
    async def get_by_id(self, id: str) -> Optional[T]:
        """Get entity by ID"""
        pass
    
    @abstractmethod
    async def update(self, entity: T) -> T:
        """Update an existing entity"""
        pass
    
    @abstractmethod
    async def delete(self, entity: T) -> None:
        """Delete an entity"""
        pass
