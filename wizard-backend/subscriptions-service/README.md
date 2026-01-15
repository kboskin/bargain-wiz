# Subscriptions Service

Microservice for managing user subscriptions with Apple App Store and Google Play integration.

## Architecture

- **FastAPI** - Modern Python web framework
- **Uvicorn** - ASGI server with async support
- **SQLAlchemy Async** - Async database operations
- **aiohttp** - Coroutine-based HTTP client
- **PostgreSQL** - Database (via asyncpg)

## Features

- Receipt verification with App Store/Play Store
- Webhook handling for subscription events
- Database models following article architecture
- Dockerized for easy deployment

## Setup

### Using uv (Recommended)

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
uv sync

# Run service
uv run uvicorn app.main:app --reload
```

### Using Docker

```bash
# Build and run with docker-compose
docker-compose up --build

# Service will be available at http://localhost:8000
```

## Environment Variables

Copy `.env.example` to `.env` and configure:

- `DATABASE_URL` - PostgreSQL connection string
- `APPLE_SHARED_SECRET` - From App Store Connect
- `GOOGLE_CREDENTIALS_PATH` - Path to Google service account JSON
- `FIREBASE_CREDENTIALS_PATH` - Path to Firebase admin credentials

## API Documentation

Once running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Database Migrations

```bash
# Create migration
alembic revision --autogenerate -m "Initial migration"

# Apply migrations
alembic upgrade head
```
