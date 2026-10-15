from fastapi import FastAPI, HTTPException
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from spacedrift_api.settings import settings
from spacedrift_api.routes import router

app = FastAPI(
    title="Spacedrift Client Approval API",
    version="0.1.0",
    description="Version-specific review and approval service.",
)
app.include_router(router)


@app.get("/health/live", tags=["health"])
def liveness() -> dict[str, str]:
    """Process liveness; does not imply database or integration readiness."""
    return {"status": "alive"}


@app.get("/health/ready", tags=["health"])
def readiness() -> dict[str, str]:
    """Readiness requires the configured PostgreSQL service to answer."""
    if settings.database_url is None:
        raise HTTPException(status_code=503, detail="database_not_configured")

    engine = create_engine(
        settings.database_url,
        pool_pre_ping=True,
        connect_args={"options": "-c timezone=UTC"},
    )
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="database_unavailable") from exc
    finally:
        engine.dispose()
    return {"status": "ready"}
