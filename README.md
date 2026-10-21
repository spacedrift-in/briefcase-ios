# Spacedrift Client Approval

Spacedrift is an iOS and FastAPI prototype for version-specific client review, change requests, approvals, and auditable history. The current SwiftUI application is a local synthetic demonstration; live service connections are not configured.

## Current status

Discovery and architecture are documented in [`docs/architecture.md`](docs/architecture.md), [`docs/open-decisions.md`](docs/open-decisions.md), and [`docs/decisions/`](docs/decisions/). The Swift package includes review rules, a URLSession API client, and a Core Data summary cache. The backend covers authenticated project scoping, decision recording, and audit export. A SwiftUI iOS target now demonstrates local project review, distinct synthetic roles, version-specific decisions, revisions, and a local audit history. It is not connected to the API/cache/authentication and does not upload files.

## Environment observed

- Swift 6.4 and Xcode 27.0 are installed, with iOS 27.0 SDKs.
- CoreSimulator could not connect; no available simulator runtimes were discovered.
- Python 3.13.16 is installed.
- Docker CLI 29.8.1 is installed, but its daemon socket is unavailable.
- `psql` is not installed.
- The verified checkout is `main` at `cec8db235c7bf912e918f59d4b20290f90f681e3`; see [release-candidate status](docs/release-candidate-status.md).

## Documentation

- [Architecture and verified baseline](docs/architecture.md)
- [Setup and environment status](docs/setup.md)
- [Demo plan and current limitations](docs/demo.md)
- [Open product and technical decisions](docs/open-decisions.md)
- [Data model proposal](docs/data-model.md)
- [API contract proposal](docs/api-contract.md)
- [Security principles](docs/security.md)
- [Testing plan and verified commands](docs/testing.md)
- [Release-candidate verification status](docs/release-candidate-status.md)
- [Backend setup](backend/README.md)

The target acceptance date in the brief is 10 November 2026, a planning target only. Current verification, Linear status, and remaining release gates are tracked in [release-candidate status](docs/release-candidate-status.md).

## Current code and validation

- [`ios/SpacedriftApp`](ios/SpacedriftApp) contains the iOS 16+ SwiftUI target and local fixture walkthrough. The target links the local `SpacedriftCore` Swift package.
- [`ios/SpacedriftCore`](ios/SpacedriftCore) contains domain rules, the URLSession API client, the read-only Core Data cache, and XCTest coverage.
- The core suite passed 13 tests on macOS 14 with SwiftPM's per-command sandbox workaround. The app and core sources passed an iOS 16 target type-check. The local Xcode build remains blocked at package resolution by host sandbox/cache restrictions; hosted iOS and backend CI passed for base commit `cec8db2`. Simulator and device launch have not been verified. No CI run or PR exists yet for the local release-readiness branch; see the [verification status](docs/release-candidate-status.md).
- The sandbox flag is required because this host cannot apply SwiftPM's subprocess sandbox. See [testing notes](docs/testing.md).
- `cd backend && .venv/bin/python -m pytest` passed 12 tests on Python 3.13.16 using isolated SQLite fixtures. PostgreSQL integration and migrations have not been executed against a database.
- [iOS demo walkthrough and build command](docs/demo.md)
