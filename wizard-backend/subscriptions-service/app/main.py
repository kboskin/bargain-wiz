"""FastAPI application entry point"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.router import router as subscriptions_router
from app.database.db import init_db
from app.config import settings
import uvicorn

app = FastAPI(
    title=settings.api_title,
    version=settings.api_version,
    description="Microservice for managing user subscriptions",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include consolidated router
app.include_router(subscriptions_router)


@app.on_event("startup")
async def startup_event():
    """Initialize database on startup"""
    await init_db()


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "subscriptions-service"}


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
        log_level="info"
    )
