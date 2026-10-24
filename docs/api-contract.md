# API contract status

This document describes routes present in `backend/spacedrift_api`. All `/api/v1` routes require a verified bearer token and server-side workspace/project authorization. Responses must not reveal whether an inaccessible resource exists. The Swift client has typed methods for health, project/version metadata, comments, decisions, and audit. The SwiftUI app still uses its local demo adapter for the walkthrough and has no configured sign-in/token provider.

## Implemented routes

- `GET /health/live` — implemented and tested; process liveness only, no database assertion.
- `GET /health/ready` — implemented and tested for missing database configuration; when configured, executes `SELECT 1` against PostgreSQL.
- `GET /api/v1/projects` — implemented and tested with SQLite fixtures; lists projects for active workspace and project memberships.
- `GET /api/v1/projects/{project_id}` — implemented and tested; returns only a project the authenticated subject can access.
- `GET /api/v1/projects/{project_id}/timeline` — implemented and tested; authorized version summaries with derived review status.
- `GET /api/v1/versions/{version_id}` — implemented and tested; returns authorized metadata without exposing the private storage key.
- `GET /api/v1/versions/{version_id}/comments` — implemented and tested; lists comments for an authorized project member.
- `POST /api/v1/versions/{version_id}/comments` — implemented and tested; only the assigned `client_reviewer` role may add a non-empty comment; `Idempotency-Key` makes retries safe.
- `POST /api/v1/versions/{version_id}/decisions` — implemented and tested; exact-version decision, client-reviewer role, `Idempotency-Key`, and audit transaction.
- `GET /api/v1/projects/{project_id}/audit-export?format=json|csv` — implemented and tested for active project members; includes review decisions and append-only version comments (`decision_id` is null for comment records).

OIDC signature/claim validation also has unit tests. Route tests use synthetic identity overrides and SQLite, not a live identity provider or PostgreSQL service. No provider has been configured. The app can check liveness/readiness without authentication, but project/timeline data cannot be loaded until an approved identity provider and native token/session implementation are configured. The local Client/Consultant/Restricted selector is not server authentication.

## Not implemented routes

- `POST /api/v1/versions` — create upload intent with project/deliverable authorization and idempotency key.
- `POST /api/v1/versions/{version_id}/complete-upload` — validate uploaded object metadata, finalize version.
- `GET /api/v1/versions/{version_id}/download` — authorize then return a short-lived private download capability.
Upload/download routes remain unimplemented pending maximum file size and storage provider configuration.

## Contract requirements

- Use opaque IDs and UTC server timestamps.
- Mutations include an `Idempotency-Key`; repeated keys return the original result or a conflict if reused with a different request body.
- State-changing requests include an expected version/state token (such as `If-Match`) to reject stale transitions.
- Return typed errors for unauthenticated, forbidden/not-found, validation, conflict, rate limit, and transient server failures. Do not include secrets, storage keys, or restricted project metadata in errors.
- Approval response includes the exact immutable version ID, authenticated actor identity, decision ID, and server timestamp. The client only displays confirmed success after receiving/reconciling authoritative state.
- Upload intent, binary upload, and completion are separate so interrupted transfers can be retried without prematurely publishing a version.

Identity provider, exact page/sync metadata, upload/file-transfer mechanism, and approved export roles remain undecided. Existing service provider names are unknown; the implementation is configured through provider-neutral OIDC and PostgreSQL settings.
