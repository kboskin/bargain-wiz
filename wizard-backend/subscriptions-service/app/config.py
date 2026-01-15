"""Configuration settings for subscriptions service"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings"""
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
        env_file_encoding="utf-8",
    )
    
    # API Configuration
    api_title: str = "Subscriptions Service"
    api_version: str = "1.0.0"
    
    # Database
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/subscriptions_db"
    
    # Apple App Store
    apple_shared_secret: str = ""
    apple_sandbox: bool = True
    
    # Google Play
    google_package_name: str = "com.bargain.wiz"
    google_credentials_path: str = ""
    
    # Firebase (for auth verification)
    firebase_credentials_path: str = ""
    
    # CORS
    cors_origins: list[str] = ["*"]
    
    # Environment
    environment: str = "development"
    debug: bool = True
    
    # Mock mode (for development/testing without real credentials)
    use_mock_verifiers: bool = False
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
