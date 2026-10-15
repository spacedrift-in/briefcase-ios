import asyncio

import httpx

from spacedrift_api.main import app


async def get(path: str) -> httpx.Response:
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.get(path)


def test_liveness_does_not_claim_database_readiness() -> None:
    response = asyncio.run(get("/health/live"))

    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


def test_readiness_reports_missing_database_configuration(monkeypatch) -> None:
    from spacedrift_api import main

    monkeypatch.setattr(main.settings, "database_url", None)
    response = asyncio.run(get("/health/ready"))

    assert response.status_code == 503
    assert response.json()["detail"] == "database_not_configured"
