from collections.abc import Generator
from functools import lru_cache

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from spacedrift_api.settings import settings


@lru_cache(maxsize=1)
def get_session_factory() -> sessionmaker[Session]:
    if not settings.database_url:
        raise HTTPException(status_code=503, detail="database_not_configured")
    engine = create_engine(
        settings.database_url,
        pool_pre_ping=True,
        connect_args={"options": "-c timezone=UTC"},
    )
    return sessionmaker(bind=engine, expire_on_commit=False)


def get_session() -> Generator[Session, None, None]:
    factory = get_session_factory()
    with factory() as session:
        yield session
