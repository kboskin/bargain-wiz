"""Subscription database models"""
from sqlalchemy import (
    Column,
    String,
    Boolean,
    DateTime,
    Enum,
    Index,
    ForeignKey,
    ForeignKeyConstraint,
    BigInteger,
    JSON,
)
from sqlalchemy.sql import func
from app.database.db import Base
import enum


class SubscriptionTier(str, enum.Enum):
    """Subscription tier enum"""
    FREE = "free"
    BASIC = "basic"
    PREMIUM = "premium"


class AccountSubscription(Base):
    """Current active subscription per user"""
    __tablename__ = "account_subscriptions"

    user_id = Column(String, primary_key=True)  # Firebase UID
    original_transaction_id = Column(String, nullable=False)
    plan_id = Column(String, nullable=False)  # Product ID
    tier = Column(Enum(SubscriptionTier), nullable=False)
    is_active = Column(Boolean, default=False)
    auto_renew_status = Column(Boolean, default=True)
    expires_date = Column(DateTime(timezone=True))
    platform = Column(String, nullable=False)  # 'ios' or 'android'
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index('idx_original_transaction_id', 'original_transaction_id'),
        Index('idx_user_id', 'user_id'),
    )


class SubscriptionReceipt(Base):
    """Chronological receipt history"""
    __tablename__ = "subscription_receipts"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String, nullable=False, index=True)
    original_transaction_id = Column(String, nullable=False, index=True)
    transaction_id = Column(String, nullable=False, index=True)
    receipt_data = Column(JSON, nullable=False)  # Full receipt data from Apple/Google
    plan_id = Column(String, nullable=False)
    purchase_date = Column(DateTime(timezone=True), nullable=False)
    expires_date = Column(DateTime(timezone=True))
    is_trial_period = Column(Boolean, default=False)
    is_in_intro_offer_period = Column(Boolean, default=False)
    platform = Column(String, nullable=False)
    verified_at = Column(DateTime(timezone=True), server_default=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        ForeignKeyConstraint(['user_id'], ['account_subscriptions.user_id'], ondelete='CASCADE'),
    )
