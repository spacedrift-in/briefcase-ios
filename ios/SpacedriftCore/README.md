# SpacedriftCore

Provider-neutral domain package for review decisions tied to immutable deliverable versions. It currently validates that:

- Requesting changes requires a non-empty comment.
- Approval and request changes are terminal for that version.
- A new version begins in `awaitingReview` and does not inherit a prior decision.
- Mutation requests carry a version ID and idempotency key; actor and timestamp are intentionally server-owned.

The package also contains a typed `URLSession` client for the implemented FastAPI routes. `APIConfiguration` validates an explicit HTTP(S) base URL and configures a finite request timeout. Liveness/readiness health requests do not require a token; protected project, timeline, audit, and decision requests require an injected `AccessTokenProviding` implementation. The app has no such provider yet, so authenticated reads/mutations are not wired into the UI. Run its tests from this directory with `swift test --disable-sandbox`. The package test run targets macOS and does not constitute an iOS app build.
