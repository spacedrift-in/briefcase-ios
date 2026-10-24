# Backend

FastAPI service foundation for Spacedrift. It currently includes generic OIDC RS256 validation, PostgreSQL configuration, workspace/project membership models, authorized project/version/timeline reads, version comments and decisions, idempotent writes, an audit event transaction, audit JSON/CSV export, and Alembic schemas.

## Install

From this directory, on Python 3.13:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.lock
```

## Test

```sh
.venv/bin/python -m pytest
```

Tests use an isolated in-memory SQLite database and synthetic identity claims. They are not PostgreSQL or external identity integration tests.

## Configure and run

Copy the repository-root `.env.example` to `backend/.env`; set `DATABASE_URL` to the Supabase PostgreSQL URL in the commented example and keep the password local. Configure the documented OIDC issuer, audience, and JWKS URL after enabling RS256 signing in Supabase Auth. Then apply migrations and start the server:

```sh
.venv/bin/alembic upgrade head
.venv/bin/uvicorn spacedrift_api.main:app --reload
```

`GET /health/live` is independent of backing services. `GET /health/ready` requires `DATABASE_URL`. Protected API calls additionally require a correctly configured OIDC issuer, audience, and JWKS URL plus seeded workspace/project membership rows.

## Implemented routes and limits

See [`../docs/api-contract.md`](../docs/api-contract.md). File upload/download, demo membership seeding, refresh/session revocation, and pagination/sync cursors are not implemented. Do not expose this API to real users until PostgreSQL integration, provider configuration, migrations, file-transfer support, and security review have been completed.
