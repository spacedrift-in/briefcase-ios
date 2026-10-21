# Demonstration plan

## Current status

The SwiftUI local synthetic walkthrough is implemented in `ios/SpacedriftApp`. It has a client reviewer, consultant, and restricted account selector; one review project plus one restricted project; version-specific decisions; synthetic revisions; and a local audit list. It starts with version 1 awaiting review. The banner and mutation notices state that fixture changes are local and not server-confirmed. No files are transferred.

The current interface uses a warm editorial style with a project overview, versioned deliverable rows, a synthetic preview, version comparison, a validated feedback sheet, exact-version approval confirmation, and a chronological local activity view. The consultant can open the restricted-project fixture; the other demo roles receive an access-denied notice. Role switching remains available from the header menu. These are client-side fixtures and are not production authorization or server records.

## Proposed walkthrough

1. Open the app; it starts as the `Client reviewer` fixture.
2. Open `Northstar identity` → Version 1 and request changes with a comment.
3. Return to the project, use the account menu to select `Consultant`, then choose `Create synthetic revision`.
4. Select `Client reviewer` again and open Version 2. It has its own `Awaiting review` state; Version 1 remains `Changes requested`.
5. Approve Version 2 and inspect Audit history. Each event names the acting fixture subject and exact version.
6. Select `Restricted account` and tap `Confidential launch`; the fixture denies access. Select `Consultant` to see the allowed fixture path.

Build from the repository root on a configured Xcode host:

```sh
xcodebuild -project ios/SpacedriftApp/SpacedriftApp.xcodeproj \
  -scheme SpacedriftApp -destination 'generic/platform=iOS' \
  -derivedDataPath work/DerivedData \
  -clonedSourcePackagesDirPath work/SourcePackages \
  -packageCachePath work/PackageCache CODE_SIGNING_ALLOWED=NO build
```

The app and core sources pass an iOS 16 SDK type-check, and the core package currently passes 13 tests. GitHub Actions successfully built the app for generic iOS and ran core tests for commit `cec8db2`. The local Xcode build was attempted but cannot resolve the package because this host cannot launch SwiftPM's manifest sandbox or write its diagnostics under the user's Library cache. Simulator run instructions cannot be verified here because CoreSimulatorService is unavailable. On a normal Xcode installation, open `ios/SpacedriftApp/SpacedriftApp.xcodeproj`, select the `SpacedriftApp` scheme and an iOS 16+ simulator, then Run. See [release-candidate status](release-candidate-status.md) for exact evidence and limits.

## Limitations to disclose

The app fixture is in-memory: actions disappear when the process restarts, are not sent to a server, do not create a persisted audit record, and create file names without file bytes. It does not demonstrate live cache/offline behavior, sign-in/session expiry, API conflict or uncertain states, PDF viewing, or live authorization. The backend still uses synthetic identities and SQLite tests. Identity, database, and private storage providers remain unidentified. Do not present this as a production approval record.
