# Setup

## Current status

The backend tests can run locally and an iOS 16+ SwiftUI target is present. The app retains its synthetic fixture workflow and now performs a configurable API liveness/readiness check. It does not fetch project data: `/api/v1/projects` is authenticated, and no identity provider, native sign-in flow, or access-token provider has been selected/configured. The local demo roles are not server identities. PostgreSQL-backed API use still requires an existing PostgreSQL endpoint and OIDC issuer/JWKS configuration; provider names and credentials have not been supplied.

For the verified release-branch commit and validation results, see [release-candidate status](release-candidate-status.md). Hosted CI built `main` at `cec8db2`; generic device and Simulator builds pass for the local release-readiness branch when Xcode runs outside the restricted shell. No hosted CI run exists yet for this local branch.

## Prerequisites observed

- macOS with Swift 6.4 and Xcode 27.0; iOS SDK 27.0 is installed.
- Python 3.13.16 is installed.
- Docker CLI 29.8.1 is installed, but the Docker daemon is not running/reachable.
- CoreSimulatorService was unavailable and no simulator runtimes were discoverable.
- `psql` is not installed.

## iOS app build

The project links `ios/SpacedriftCore` as a local Swift package (`../SpacedriftCore` relative to the Xcode project). The manifest declares no external packages. The checked-in shared `SpacedriftApp` scheme targets iOS; Debug and Release set `SDKROOT=iphoneos`, `SUPPORTED_PLATFORMS=iphoneos iphonesimulator`, and minimum iOS 16.0.

In normal macOS Terminal or Xcode, outside the restricted Codex execution environment, from the repository root, resolve the project package and build for a generic iOS device with signing disabled:

```sh
xcodebuild -resolvePackageDependencies \
  -project ios/SpacedriftApp/SpacedriftApp.xcodeproj \
  -scheme SpacedriftApp

xcodebuild build -project ios/SpacedriftApp/SpacedriftApp.xcodeproj \
  -scheme SpacedriftApp -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

In the restricted Codex shell, Xcode package resolution fails because the environment cannot launch macOS `sandbox-exec` subprocesses. Running the generic device and Simulator builds outside that shell succeeds with the commands above. Do not disable macOS security globally. See [testing](testing.md) for captured results and the precise diagnosis.

Earlier restricted-shell attempts exited 74 at package resolution because Xcode could not write the SwiftPM manifest diagnostic under `~/Library/Caches/org.swift.swiftpm`. Generic device and Simulator builds succeeded outside that shell. CoreSimulatorService is unavailable, so no simulator runtime workflow was run. A signed build was installed and launched on the paired iPhone 16, and the synthetic approval/revision/restricted-access walkthrough plus termination/relaunch reset were exercised there. See [testing](testing.md) for the verified evidence and remaining accessibility/performance checks.

For an interactive simulator run, open the project in Xcode and select the shared `SpacedriftApp` scheme with an iOS 16+ iPhone runtime. CoreSimulatorService is unavailable on this host, so simulator launch remains unverified. The synthetic approval workflow has been exercised on the paired iPhone 16; this does not replace simulator automation or formal VoiceOver/Dynamic Type review. The app Swift source separately passed iOS 16 SDK type-checking using the local core module.

To verify the local package independently in this restricted environment (SwiftPM command tested successfully):

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/spacedrift-spm-clang-cache \
  SWIFT_MODULECACHE_PATH=/private/tmp/spacedrift-spm-swift-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/spacedrift-spm-module-cache \
  swift package --package-path ios/SpacedriftCore --disable-sandbox resolve

env CLANG_MODULE_CACHE_PATH=/private/tmp/spacedrift-spm-clang-cache \
  SWIFT_MODULECACHE_PATH=/private/tmp/spacedrift-spm-swift-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/spacedrift-spm-module-cache \
  swift build --package-path ios/SpacedriftCore --disable-sandbox \
    --scratch-path /private/tmp/spacedriftcore-build \
    -Xswiftc -module-cache-path -Xswiftc /private/tmp/spacedrift-spm-clang-cache
```

## Backend setup

1. Install a supported Xcode version and an iOS simulator runtime; verify with `xcodebuild -version` and `xcrun simctl list devices available`.
2. Install the pinned Python version and backend dependencies from the committed lockfile.
3. Start PostgreSQL using the documented local or test environment and verify connectivity without printing credentials.
4. Copy the repository-root `.env.example` to `backend/.env` and populate only local development values. The supplied PostgreSQL URL is a template and the OIDC values are blank, not working credentials.
5. Run `.venv/bin/alembic upgrade head` against the configured PostgreSQL database. There is currently no membership/project seed command, so protected API requests need membership rows provisioned through a controlled development/test process.
6. Start the API on a host reachable from the phone, for example `.venv/bin/uvicorn spacedrift_api.main:app --host 0.0.0.0 --port 8000`. Liveness works without database/OIDC configuration; readiness returns 503 until PostgreSQL answers.
7. Set `SpacedriftAPIBaseURL` in `ios/SpacedriftApp/SpacedriftApp-Info.plist` to the API root URL. Simulator can use `http://127.0.0.1:8000/`. A physical iPhone must use a Mac-reachable hostname (for example `http://<mac-name>.local:8000/`) or HTTPS; do not use `localhost` or `127.0.0.1` on the phone. Keep the devices on a network that allows local peer traffic and accept the iOS Local Network prompt. The app's ATS exception is limited to local networking; remote plain HTTP is not enabled.
8. Build and install the existing `SpacedriftApp` scheme. The dashboard status reports API process liveness separately from database readiness. A live response does not enable project sync or prove authenticated access.

The iOS target and backend code are implemented, but live service setup is not verified. Never commit secrets or production credentials. The synthetic app demo does not need backend services.

## Verified domain package command

Run the command documented in [testing](testing.md) from the repository root. The latest core run passed 13 domain/cache/API client tests on macOS. It does not build the iOS app.

## Backend install and tests

From the repository root:

```sh
cd backend
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.lock
.venv/bin/python -m pytest
```

To run the API locally, copy the repository-root `.env.example` to `backend/.env`, fill in existing PostgreSQL and OIDC settings, then run `.venv/bin/alembic upgrade head` and `.venv/bin/uvicorn spacedrift_api.main:app --host 0.0.0.0 --port 8000`. These live service steps depend on valid services and have not been verified against them. The current backend tests can run without those services.

## API milestone

`SpacedriftCore` provides typed API configuration, an 8-second URLSession timeout, unauthenticated typed health checks, and protected typed project/timeline/audit/decision calls. The dashboard runs `/health/live` and then `/health/ready`, with retry and explicit status text. The project-list route exists and is represented by `ProjectSummary`, but the app does not call it because no real token provider is configured; no synthetic server response is substituted. Approval decisions remain local demo actions and are not submitted to the API.

The central app URL key is `SpacedriftAPIBaseURL` in `SpacedriftApp-Info.plist`. Change that key for the selected build destination, then rebuild/reinstall. Per-destination Xcode build configurations can be added when actual development hosts are known.
