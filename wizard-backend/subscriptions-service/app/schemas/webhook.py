"""Webhook request schemas"""
from pydantic import BaseModel, Field
from typing import Optional, Any


class AppleWebhookNotification(BaseModel):
    """Apple App Store Server Notification schema"""
    notification_type: str = Field(..., description="Notification type (e.g., DID_RENEW, CANCEL)")
    unified_receipt: dict[str, Any] = Field(..., description="Unified receipt data")
    original_transaction_id: str = Field(..., description="Original transaction ID")
    webhook_environment: str = Field(..., pattern="^(Sandbox|Production)$")
