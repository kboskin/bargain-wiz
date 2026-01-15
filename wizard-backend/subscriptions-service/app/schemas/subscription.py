"""Subscription request/response schemas"""
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class VerifyReceiptRequest(BaseModel):
    """Request schema for receipt verification"""
    receipt_data: str = Field(..., description="Base64 receipt (iOS) or purchase token (Android)")
    transaction_id: Optional[str] = None
    original_transaction_id: Optional[str] = Field(None, description="Original transaction ID (iOS)")
    platform: str = Field(..., pattern="^(ios|android)$")
    user_id: str = Field(..., description="Firebase UID")
    product_id: str = Field(..., description="Product ID (e.g., com.bargain.wiz.premium)")
    sandbox: bool = Field(default=False, description="Whether this is a sandbox purchase")


class SubscriptionStatusResponse(BaseModel):
    """Response schema for subscription status"""
    tier: str = Field(..., description="Subscription tier: free, basic, or premium")
    is_active: bool
    expiry_date: Optional[datetime] = None
    product_id: Optional[str] = None
    original_transaction_id: Optional[str] = None
    verified: bool = True

    class Config:
        json_schema_extra = {
            "example": {
                "tier": "premium",
                "is_active": True,
                "expiry_date": "2025-12-31T23:59:59Z",
                "product_id": "com.bargain.wiz.premium",
                "original_transaction_id": "1000000123456789",
                "verified": True
            }
        }


class ErrorResponse(BaseModel):
    """Error response schema"""
    error: str
    message: str
    code: Optional[str] = None
    details: Optional[dict] = None
