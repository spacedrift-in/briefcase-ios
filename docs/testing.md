# Testing and validation

## Current release-candidate recheck (2026-10-24)

- Added authorized project/version detail reads and idempotent version-comment routes, with denied cross-project access and reviewer-role checks covered by backend tests.
- `backend` suite: 15 tests passed using the Python 3.13 environment available from the workspace snapshot. It uses SQLite and synthetic identity claims; PostgreSQL and live OIDC remain unverified.
- `ios/SpacedriftCore` suite: 15 tests passed, including authenticated idempotent comment submission and audit export records whose comments do not have decision IDs. This compiles and tests the client library on macOS; it does not run the iOS app.
- The commit containing these changes has not yet been pushed, so PR CI must run on the updated head before merge.
- PostgreSQL is user-approved as the target service, but no reachable endpoint or credentials are configured. OIDC and private-storage provider names are not present in repo config. The upload-size limit is still open.

## Current release-candidate recheck (2026-10-21)

Follow-up on branch `codex/briefcase-release-readiness` at docs-only commit `5151d10`: `xcodebuild` successfully compiled and linked the app for generic iOS device and generic iOS Simulator destinations with signing disabled when run outside the restricted shell. The Swift core suite passed **13 tests, 0 failures** and the backend suite passed **12 tests, 0 failures**. On the paired iPhone 16, the full synthetic approval walkthrough was exercised: Version 1 change request, consultant-created Version 2, client approval of that exact version, local audit inspection, and restricted-project denial. Force-quit and relaunch returned to the initial Client/Version 1 pending state, confirming that demo state is in-memory and not persistent. CoreSimulatorService is unavailable, so no simulator runtime workflow could be run.

The base checkout was `main` at `cec8db235c7bf912e918f59d4b20290f90f681e3`, clean before this review. The Swift core suite passed **13 tests, 0 failures** with the documented per-command sandbox option; the backend suite passed **12 tests, 0 failures**. The app and core sources passed an iOS 16 target type-check against the installed iOS 27 SDK. The core package resolved without external dependencies and built for `arm64-apple-ios16.0`.

Both hosted workflows are green for that exact base SHA: [iOS run 38774565079](https://github.com/spacedrift-in/briefcase-ios/actions/runs/38774565079) ran the generic iOS app build and core tests; [Backend run 38774564990](https://github.com/spacedrift-in/briefcase-ios/actions/runs/38774564990) installed the lockfile and ran pytest. They predate this review's changes; no run or PR exists for the local branch yet. There is no separate RC tag.

The restricted-shell Xcode device/Simulator builds still fail before compilation at SwiftPM manifest diagnostics with `Operation not permitted`; successful generic builds were run outside that shell without changing project security settings. After the latest accessibility color adjustment, generic device and Simulator builds passed again, and a signed device build installed and launched on iPhone 16. The tertiary metadata color now has computed contrast of at least 4.60:1 against the app's paper, surface, and muted card backgrounds. This color-token calculation and visual check do not replace a VoiceOver/Dynamic Type accessibility review. CoreSimulatorService is unavailable. Instruments App Launch profiling was retried and again timed out waiting for the device to boot. See [release-candidate status](release-candidate-status.md) for the full scope and remaining gates.

## Backend connectivity milestone (2026-10-15)

- `ios/SpacedriftCore` tests passed **13 tests, 0 failures**, including seven new API client/configuration tests for health success, typed project decoding, missing auth, HTTP 503, malformed JSON, connection failure, and invalid URLs. The tests used SwiftPM's supported per-command `--disable-sandbox` flag and scratch/module caches under `/private/tmp`.
- Backend tests passed **12 tests, 0 failures** with `cd backend && .venv/bin/python -m pytest`.
- The existing `SpacedriftApp` scheme built successfully via Xcode's GUI (`Product > Build`, selected iPhone destination, signing configuration left intact). The report shows the SpacedriftCore and SpacedriftApp targets compiled, linked, and signed; it finished with one existing orientation warning: “All interface orientations must be supported unless the app requires full screen.” This validates compilation/linking only; the app was not manually exercised on the physical phone.
- The same build attempted via `xcodebuild build -project ios/SpacedriftApp/SpacedriftApp.xcodeproj -scheme SpacedriftApp -destination 'generic/platform=iOS' -derivedDataPath work/DerivedData CODE_SIGNING_ALLOWED=NO` exited 74 during SwiftPM resolution, before compilation, with `cannot open file '/Users/chiragkumar/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading/spacedriftcore.dia' for diagnostics emission (Operation not permitted)`. No sandbox/security setting was changed. Xcode's GUI build succeeded using the existing Xcode package state.
- API endpoint behavior was tested against URLProtocol stubs in the Swift package and existing FastAPI tests, not against a running external server. No PostgreSQL/OIDC provider or credentials are configured. Therefore liveness/readiness can be queried by the app once `SpacedriftAPIBaseURL` is set, but authenticated project fetching is not enabled.

Command used for current Swift package tests:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/spacedrift-spm-clang-cache \
  SWIFT_MODULECACHE_PATH=/private/tmp/spacedrift-spm-swift-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/spacedrift-spm-module-cache \
  swift test --package-path ios/SpacedriftCore --disable-sandbox \
    --scratch-path /private/tmp/spacedriftcore-phase2-tests \
    -Xswiftc -module-cache-path -Xswiftc /private/tmp/spacedrift-spm-clang-cache
```

## Verified status

A provider-neutral Swift package exists at `ios/SpacedriftCore`. The following command passed **6 tests, 0 failures** on macOS 14. Host cache/sandbox restrictions required the temporary paths shown here:

```sh
cd ios/SpacedriftCore
env CLANG_MODULE_CACHE_PATH=/private/tmp/spacedrift-clang-cache \
  SWIFT_MODULECACHE_PATH=/private/tmp/spacedrift-swift-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/spacedrift-spm-module-cache \
  swift test --disable-sandbox \
    --scratch-path /private/tmp/spacedrift-swift-build \
    -Xswiftc -module-cache-path -Xswiftc /private/tmp/spacedrift-clang-cache
```

These tests cover review transitions, Core Data cache freshness/invalidation/persistence, and compile the URLSession API client for macOS. The package (including Core Data) also built for the iOS 16 deployment triple with Xcode's iOS SDK; this is not an Xcode application build and does not run on a simulator.

```sh
cd ios/SpacedriftCore
env CLANG_MODULE_CACHE_PATH=/private/tmp/spacedrift-ios-clang-cache \
  SWIFT_MODULECACHE_PATH=/private/tmp/spacedrift-ios-swift-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/spacedrift-ios-spm-cache \
  swift build --disable-sandbox --triple arm64-apple-ios16.0 \
    --scratch-path /private/tmp/spacedrift-ios-build \
    -Xswiftc -sdk -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk \
    -Xswiftc -module-cache-path -Xswiftc /private/tmp/spacedrift-ios-clang-cache
```

The backend command `cd backend && .venv/bin/python -m pytest` passed **12 tests, 0 failures** on Python 3.13.16. Tests cover OIDC JWT claim validation, liveness/readiness, workspace/project membership isolation, reviewer role checks, comment validation, approval idempotency, exact-version audit persistence, pending state on a new version, and JSON/CSV export. API tests use synthetic identity claims and SQLite fixtures; they do not verify PostgreSQL transaction behavior or a real OIDC service.

The same 12 tests passed in a fresh temporary virtual environment installed from `backend/requirements.lock`. `alembic upgrade head --sql` rendered the PostgreSQL migration successfully in offline mode. The FastAPI server also started locally: `/health/live` returned 200 and `/health/ready` returned 503 with `database_not_configured`, as expected without a configured database.

## UI redesign validation (2026-10-15)

- The redesigned SwiftUI source passed an iOS 16 type-check against the installed iOS 27 SDK with no diagnostics. This confirms source-level type/API availability for the selected deployment triple; it does not link or package the app.
- The existing Swift core suite passed again: **6 tests, 0 failures**, using SwiftPM's per-command sandbox opt-out and temporary cache/build paths. The ordinary `swift test` command was also attempted and stopped while compiling the manifest with `sandbox-exec: sandbox_apply: Operation not permitted`.
- The requested full Xcode device build was attempted with `xcodebuild build -project ios/SpacedriftApp/SpacedriftApp.xcodeproj -scheme SpacedriftApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. It exited 74 during package graph resolution, before app compilation. The captured complete output is at [the UI redesign build log](../work/ui-redesign-xcodebuild.log). The immediate diagnostics include failure to write `~/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading/spacedriftcore.dia` (`Operation not permitted`); the same host also reports `sandbox_apply: Operation not permitted` on SwiftPM manifest sandbox launch. This is an execution-environment limitation. No project/package setting was changed to bypass it.
- CoreSimulatorService cannot connect and no simulator runtime is available on this host. No simulator launch, visual screenshot review, or device installation was performed. The physical iPhone workflow remains for a normal local Xcode/Terminal session.
- No backend source changed in this UI task. Previously verified backend result remains 12 passing tests; they were not rerun for this presentation-only change.

The SwiftUI app target is at `ios/SpacedriftApp`. Current dependency/build diagnosis:

- Environment verified for this run: Xcode 27.0 (27A266a), Apple Swift 6.4, active developer directory `/Applications/Xcode.app/Contents/Developer`, iPhoneOS SDK 27.0. The app references one local Swift package, `../SpacedriftCore`; `Package.swift` has no external dependencies and no `Package.resolved` is required.
- The exact requested device build and a separate `xcodebuild -resolvePackageDependencies` both stop during SwiftPM manifest sandbox startup with `sandbox-exec: sandbox_apply: Operation not permitted`. They do not reach app compilation. Full output is captured at `work/device-build-final.log` and `work/package-resolution-final.log`.
- The environment failure is independently reproducible without Xcode or this project: `sandbox-exec -p '(version 1)' /usr/bin/true` exits 71 with the same `sandbox_apply: Operation not permitted`. The local package manifest resolves and its macOS build succeeds when invoked with SwiftPM's supported per-command `--disable-sandbox` flag. Xcode's help has no equivalent sandbox option. This points to the current execution environment's restriction on macOS sandbox subprocesses, not an invalid package manifest or project package path. The Xcode app target cannot be fully built here without that sandbox facility.
- For the full Xcode build, use normal macOS Terminal or Xcode outside this restricted execution environment; do not change system security settings. Commands are in [setup](setup.md).
- Independent iOS 16 SDK type-checking of the app source surfaced actual source/API problems: `NavigationLink(_:systemImage:)` did not match the iOS 16 overload, and `ContentUnavailableView` is iOS 17-only. The link now uses a `Label` destination, and the unavailable states use standard `VStack` content.
- The standalone type-check initially reported `@main` because that invocation was not in library mode; rerunning with `-parse-as-library` removed that invocation-only diagnostic. Its SwiftUI `@State` macro expansion was also blocked by this host's sandboxed plugin server, so the request form state now lives in a small `@StateObject` view model. The final standalone iOS 16 type-check passed with no diagnostics.
- Xcode also reported `Supported platforms for the buildables in this scheme is empty`. The app target now explicitly declares `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, `SDKROOT = iphoneos`, and `IPHONEOS_DEPLOYMENT_TARGET = 16.0`; a shared `SpacedriftApp` scheme is checked in.

The direct source check used the iOS 27 SDK while targeting iOS 16. It is only a source/type-availability check, not a replacement for Xcode's full app build. To recreate its local module from the unchanged core package sources and then type-check the app source:

```sh
mkdir -p work/CoreModules
env SWIFTC_DISABLE_SANDBOX=1 \
  CLANG_MODULE_CACHE_PATH="$PWD/work/clang-cache" \
  SWIFT_MODULECACHE_PATH="$PWD/work/swift-cache" \
  xcrun swiftc -target arm64-apple-ios16.0 \
    -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk \
    -module-name SpacedriftCore -parse-as-library -emit-module \
    -emit-module-path work/CoreModules/SpacedriftCore.swiftmodule \
    ios/SpacedriftCore/Sources/SpacedriftCore/APIModels.swift \
    ios/SpacedriftCore/Sources/SpacedriftCore/ReviewState.swift \
    ios/SpacedriftCore/Sources/SpacedriftCore/ApprovalAPIClient.swift \
    ios/SpacedriftCore/Sources/SpacedriftCore/CoreDataSummaryCache.swift

env SWIFTC_DISABLE_SANDBOX=1 \
  CLANG_MODULE_CACHE_PATH="$PWD/work/clang-cache" \
  SWIFT_MODULECACHE_PATH="$PWD/work/swift-cache" \
  xcrun swiftc -typecheck -parse-as-library \
    -target arm64-apple-ios16.0 \
    -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk \
    -I work/CoreModules ios/SpacedriftApp/Sources/SpacedriftApp.swift
```

The package module used in this check was emitted from the four existing core source files with `swiftc` for `arm64-apple-ios16.0`. This checks SwiftUI source/type availability but is not a full Xcode app build or link. CoreSimulator still cannot connect, and no simulator runtime was discovered. Docker cannot connect to its daemon, so PostgreSQL migration execution and database integration tests remain blocked. At the time of this historical check, CI had not run successfully; current exact-commit CI evidence is in the section above.

## Planned coverage

- Domain tests for per-version approval transitions, stale updates, comments, idempotency, and new-version state.
- API integration tests for workspace isolation across project reads, version access, uploads/downloads, mutations, and audit export.
- Database tests for migration from empty schema and transactional audit/decision persistence.
- iOS unit tests for serialization, repositories, session expiry, cache freshness, offline behavior, and uncertain mutation reconciliation. The in-memory SwiftUI demo currently has no dedicated view-model/UI test target.
- UI tests for the client request-changes → consultant revision upload → client exact-version approval journey and restricted project denial.
- Manual accessibility review for VoiceOver, Dynamic Type, contrast, control labels, and error/retry states when a simulator is available.

Exact commands and results will be added only after runnable targets and infrastructure exist and are actually exercised.
