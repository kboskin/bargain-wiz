"""FastAPI dependencies"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from firebase_admin import auth
import firebase_admin
from app.database.db import get_db
from app.config import settings
from app.repositories.subscription_repository import SubscriptionRepository
from app.repositories.receipt_repository import ReceiptRepository
from app.repositories.subscription_repository_impl import SubscriptionRepositoryImpl
from app.repositories.receipt_repository_impl import ReceiptRepositoryImpl
from app.services.subscription_service import SubscriptionService

# Initialize Firebase Admin if not already initialized
if not firebase_admin._apps:
    if settings.firebase_credentials_path:
        cred = firebase_admin.credentials.Certificate(settings.firebase_credentials_path)
        firebase_admin.initialize_app(cred)
    else:
        # Use default credentials (for local development)
        firebase_admin.initialize_app()

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> str:
    """
    Verify Firebase ID token and return user ID
    """
    try:
        token = credentials.credentials
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
        return user_id
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}"
        )


def get_subscription_repository(
    db: AsyncSession = Depends(get_db)
) -> SubscriptionRepository:
    """Factory function for subscription repository"""
    return SubscriptionRepositoryImpl(db)


def get_receipt_repository(
    db: AsyncSession = Depends(get_db)
) -> ReceiptRepository:
    """Factory function for receipt repository"""
    return ReceiptRepositoryImpl(db)


def get_subscription_service(
    subscription_repo: SubscriptionRepository = Depends(get_subscription_repository),
    receipt_repo: ReceiptRepository = Depends(get_receipt_repository),
) -> SubscriptionService:
    """Factory function for subscription service"""
    return SubscriptionService(subscription_repo, receipt_repo)
