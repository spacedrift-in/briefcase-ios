# Architecture decision records

Records below are **proposed** unless marked as a user decision. The iOS 16 minimum is confirmed by the user; device-family support remains provisional. Discovery found no existing architecture. Significant implementation dependencies should wait until the remaining choices are accepted and compatibility is verified.

## ADR-001 — iOS minimum version and devices

- **Context:** SwiftUI app needs offline summaries, secure credential handling, picker integration, and current platform accessibility APIs.
- **Options:** Older iOS baseline with broader support and custom cache; iOS 17+ with SwiftData; higher baseline.
- **Decision:** iOS 16 minimum, per user direction. iPhone first remains the working device scope; confirm iPad layout/support separately.
- **Trade-offs:** iOS 16 excludes older devices and does not include SwiftData. Use Core Data for the read-only summary cache unless compatibility review identifies a better dependency-free option.
- **Security/consequences:** Deployment target does not replace server authorization. Validate the minimum against stakeholder device inventory and available CI simulators before release.

## ADR-002 — SwiftUI structure and state

- **Context:** Workflow spans session, project, timeline, upload, and authoritative review state.
- **Options:** MVVM, feature-oriented use cases/repositories, Redux-style global store.
- **Proposed:** Feature-oriented SwiftUI views with small `ObservableObject` presentation models (iOS 16-compatible) and async use cases/repository protocols; avoid global mutable state.
- **Trade-offs:** Explicit boundaries aid tests but introduce modest protocol/use-case structure.
- **Security/consequences:** UI state is presentation only; permission and approval decisions remain server-owned. Keep token handling out of view models.

## ADR-003 — Local persistence and cache invalidation

- **Context:** Previously fetched project summaries must remain readable offline.
- **Options:** Memory-only, Core Data, SQLite wrapper, full offline database.
- **Proposed:** Core Data read cache for summaries and metadata; no offline mutations. Store last successful sync and mark cached/stale views.
- **Trade-offs:** Native persistence without a new dependency; schema migration and cache invalidation still need explicit tests.
- **Security/consequences:** Exclude file bytes and credentials from cache. Cache is never approval evidence; clear user/workspace data on sign-out and membership/session invalidation.

## ADR-004 — Authentication and token lifecycle

- **Context:** App needs sign-in, restoration, expiry handling, and server-side permission checks.
- **Options:** OIDC authorization code with PKCE, backend-managed session, static demo token.
- **Proposed:** Select an established identity provider and authorization-code/PKCE flow if the provider supports native clients; short-lived access token, revocable refresh/session credential in Keychain. Provider remains a blocking product/security decision.
- **Trade-offs:** Secure standard flow depends on provider setup; demo provisioning has operational cost. Static app tokens are rejected.
- **Security/consequences:** Backend validates every token and membership. No production secrets or demo password embedded in app.

## ADR-005 — API versioning and errors

- **Context:** iOS/backend evolve together; conflicts and network uncertainty must be recoverable.
- **Options:** Unversioned routes, path-versioned routes, content negotiation.
- **Proposed:** `/api/v1`, typed error envelope, opaque IDs, UTC timestamps, idempotency keys for mutations, and conditional state updates.
- **Trade-offs:** Small contract overhead; explicit conflict handling supports reliable retry.
- **Security/consequences:** Error bodies must not reveal inaccessible resource content. Approval UI requires server-confirmed response or reconciliation.

## ADR-006 — PostgreSQL schema and migrations

- **Context:** Shared workflow needs transactional version/decision/audit records and tenant-scoped queries.
- **Options:** PostgreSQL with SQLAlchemy/Alembic, document database, managed backend platform.
- **Proposed:** PostgreSQL, SQLAlchemy 2.x, Alembic; verify selected Python/dependency compatibility before pinning.
- **Trade-offs:** Strong transactions and relational constraints fit the workflow; database operations are required for local demo.
- **Security/consequences:** Enforce workspace/project scopes in application queries; consider database constraints/RLS as defense in depth. Approval and audit insert must be atomic.

## ADR-007 — File storage and upload authorization

- **Context:** Revisions need private upload and download paths with interruption recovery.
- **Options:** Database blobs, public URLs, private object store, local filesystem adapter.
- **Proposed:** Storage adapter with private object storage; local filesystem implementation only for local demo. Server-authorized short-lived download capability; upload intent/transfer/finalize steps.
- **Trade-offs:** More setup than public URLs; avoids making a file URL the access-control mechanism.
- **Security/consequences:** Validate size/type/checksum and workspace scope server-side. Storage outage must not create a published version or approval.

## ADR-008 — Annotation representation and file types

- **Context:** Review feedback must attach to the exact revision; visual markup is not yet defined.
- **Options:** Version comments only, PDF/image coordinates, broad office-file support.
- **Proposed:** Version-scoped comments for the first vertical slice; defer visual coordinates until file types and document coordinate systems are confirmed.
- **Trade-offs:** Smaller, testable slice; lacks visual markup.
- **Security/consequences:** Comments reference immutable version IDs. Do not claim visual annotation support. Allowed MIME/file formats and byte limits remain a product decision.

## ADR-009 — Audit integrity and retention

- **Context:** Exportable record must identify actor, exact version, decision, and server time.
- **Options:** Mutable activity feed, immutable append-only events, cryptographically chained log.
- **Proposed:** Append-only application audit events written in the same database transaction as decision; immutable decision rows. Defer cryptographic chaining until threat model requires it.
- **Trade-offs:** Transactional audit is straightforward to demonstrate; administrators/database operators remain within trust boundary.
- **Security/consequences:** Server-generated time and actor identity; exports are permission-checked and redacted. Retention, deletion, and export scope require owner decision.

## ADR-010 — CI, tests, and distribution

- **Context:** iOS needs macOS/Xcode runners; backend needs isolated database integration checks.
- **Options:** GitHub Actions, another existing CI, manual-only workflow.
- **Proposed:** Inspect/choose CI after repository hosting is established; require macOS/Xcode build and tests plus backend lint/type/unit/integration/migration jobs using disposable PostgreSQL.
- **Trade-offs:** macOS runners add cost; simulator/UI coverage depends on runner capacity.
- **Security/consequences:** No secrets in logs; required checks fail visibly. Distribution channel and signing credentials are not available and remain open.
