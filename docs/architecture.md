# Architecture and discovery assessment

## Status

Discovery completed against the provided product brief and the current workspace on 15 October 2026. The workspace was initially empty apart from its `outputs/` and `work/` directories; it is not a Git repository. No application, backend, manifests, tests, migrations, CI, or existing documentation were present. A provider-neutral Swift domain package and tests have since been added; see [testing](testing.md).

## Verified environment

| Area | Observed | Consequence |
|---|---|---|
| Swift | 6.4 (`swift --version`) | Compiler available; no project to compile. |
| Xcode | 27.0 (`xcodebuild -version`) | iOS SDK available. |
| iOS SDK | 27.0 (`xcodebuild -showsdks`) | SDK is installed. |
| Simulator | `xcrun simctl list devices available` failed because CoreSimulatorService was unavailable; no runtimes discoverable | Simulator build/run and UI tests are blocked in this environment. |
| Python | 3.13.16 | Pinned backend requirements installed and all 12 backend tests passed; live PostgreSQL/OIDC compatibility is not verified. |
| Docker | CLI 29.8.1; daemon socket unavailable | PostgreSQL container cannot currently be started. |
| PostgreSQL CLI | `psql` not found | No local database client verified. |
| Git | The initial pasted snapshot was not a repository. The actual checkout is now `main` at `cec8db2`; see [release-candidate status](release-candidate-status.md). | Current review is tied to an actual commit. |
| Linear | Briefcase iOS project and related issue data were available during the 2026-10-21 review. | Relevant issue state and the mismatched FieldProof demo ticket are summarized in [release-candidate status](release-candidate-status.md); no issues were changed. |

Commands actually run include `git status --short --branch`, `git log -5 --oneline`, `rg --files`, `swift --version`, `xcodebuild -version`, `python3 --version`, `command -v psql`, `command -v docker`, `command -v gh`, `command -v linear`, `xcodebuild -showsdks`, `xcrun simctl list devices available`, `docker version`, `xcodebuild -list`, and `swift test --disable-sandbox` in `ios/SpacedriftCore`. Only the Swift domain test command succeeded; it does not validate the iOS application or server.

## Proposed system boundary

- Native iOS client in SwiftUI using structured concurrency and URLSession.
- FastAPI service as the authority for identity, workspace/project authorization, versions, review decisions, and audit history.
- PostgreSQL for relational workflow data, accessed through SQLAlchemy 2.x and migrated with Alembic after dependency compatibility is checked.
- A private object-storage adapter for uploaded deliverables. A local development adapter can be used for a demo, but files must not become publicly accessible URLs.
- Core Data is implemented in `SpacedriftCore` as an iOS 16-compatible read-only cache of project summaries and relevant metadata. It is not yet wired into the SwiftUI app. Cached state can never establish approval success.
- API mutations use idempotency keys and concurrency checks; an uncertain client response is reconciled against server state before presenting success.

The proposed conceptual flow is presentation/navigation → use cases/domain rules → repository interfaces → URLSession/API and local cache adapters. Backend request handlers authenticate, authorize workspace and project membership, validate state transitions, persist database changes transactionally, and append audit events.

## Implemented foundation

- `ios/SpacedriftCore` contains review decision rules, a URLSession client for implemented project/timeline/decision/JSON audit endpoints, and a Core Data read-only metadata cache with stale markers and invalidation. The package targets iOS 16.
- `ios/SpacedriftApp` contains a SwiftUI iOS 16 application project. Its in-memory synthetic adapter demonstrates client request-changes, consultant revision creation, version-specific approval, local audit display, and restricted-project denial. The dashboard now calls the unauthenticated backend liveness and readiness endpoints using the URL configured in the app Info.plist. It still does not fetch project data: the project route requires a real bearer token, and authentication is not configured. The core API client exposes typed protected routes, but no local demo role is used as server identity. The cache and upload flows are not connected.
- `backend/spacedrift_api` contains FastAPI health routes, configurable OIDC/JWKS validation, SQLAlchemy models and dependencies, membership-scoped project/timeline routes, idempotent review decisions, and JSON/CSV audit exports.
- `backend/alembic` contains one initial PostgreSQL schema migration. Its SQL renders successfully in Alembic offline mode; it has not been applied to PostgreSQL.
- `backend/requirements.lock` pins the resolved Python dependency set. A clean temporary Python 3.13.16 environment installed from it and passed the API tests.

## Provisional product decisions

These are recommendations for the initial vertical slice, not implemented or stakeholder-approved commitments:

- Minimum iOS version is 16+, per user direction. iPhone is the working target; confirm iPad support. Use Core Data (not SwiftData) for an iOS 16 read cache.
- Start with comments attached to immutable deliverable versions. Defer coordinate-based visual annotation until file type and coordinate behavior are agreed.
- Make uploaded files PDF and common image formats only if the first milestone confirms those workflows. Set explicit server-side size limits before implementation.
- Model each version's decision independently. Request changes and approve are distinct transitions; a new version starts pending review and never inherits an older approval.
- Use opaque IDs, private storage, short-lived authorized downloads, workspace-scoped authorization, server timestamps, and append-only decision/audit history.
- Use synthetic demo accounts provisioned only in an explicit demo/test environment. Never ship demo passwords in the app.

## Data and authorization invariants

1. Every protected resource lookup is scoped by the authenticated principal's workspace membership and project permission.
2. Project, deliverable version, decision, and audit event IDs are distinct; a decision refers to one immutable version ID.
3. Approval is persisted by the backend with actor, server timestamp, and audit event in one transaction.
4. Request-changes requires a non-empty comment and records the version ID and actor.
5. A new version has its own review state, irrespective of prior versions.
6. File bytes are served only after backend authorization; storage object keys are not authorization.
7. Offline cache can display stale metadata, with last-sync information, but cannot mutate shared state or claim approval.

## Known risks and blockers

- Existing service providers are unknown; generic OIDC and PostgreSQL configuration is implemented but cannot yet be configured or integration-tested. Private file storage is not implemented. iPad support, supported files, and audit retention also need decisions.
- No simulator runtime/service, database daemon, or credentials/infrastructure were verified. iOS UI validation and PostgreSQL integration validation are therefore blocked locally. The app project parses and app/core sources passed an iOS 16 type-check; the local full Xcode build is blocked before compilation by SwiftPM sandbox/cache restrictions. Hosted CI built the committed base revision; it does not cover current uncommitted edits.
- The backend lockfile installs and tests on Python 3.13; production database and OIDC provider compatibility still need integration validation.
- The target date is about four weeks after the discovery date; the required MVP is broad. The 8–12 engineer-week estimate is provisional and should be revisited when providers, supported files, delivery ownership, and remaining feature scope are confirmed.
- The original pasted snapshot cannot carry reviewable Git changes; use the linked actual checkout for commits and branches.

## Initial effort and schedule outlook

Planning estimate only, based on the full brief and assuming decisions, repository hosting, simulator, database, and identity/storage access arrive promptly: roughly **8–12 engineer-weeks** for a production-minded MVP plus validation and handoff. This assumes one iOS/backend-capable engineer with review support; parallel specialists could reduce calendar time but not total effort. The target date of 10 November 2026 is only 26 calendar days after this discovery snapshot, so it is at high schedule risk unless scope is narrowed to the vertical slice and dependencies are unblocked immediately. Re-estimate after decision closure and a working end-to-end environment; this is not a delivery commitment.

## Next milestone

Resolve blocking items listed in [open decisions](open-decisions.md), then scaffold the smallest runnable vertical slice. Obtain a functioning simulator runtime and PostgreSQL test environment (or approved hosted equivalents), select compatible pinned dependencies, and verify exact setup/build/test commands before expanding scope.
