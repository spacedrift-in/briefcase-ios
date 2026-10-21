# Release-candidate verification status

**Checked:** 21 October 2026  
**Target acceptance date:** 10 November 2026  
**Status:** Validation is in progress; explicit stakeholder acceptance has not been recorded.

## Repository and Linear status

- Repository: [Briefcase iOS](https://github.com/spacedrift-in/briefcase-ios)
- Current checkout: branch `codex/briefcase-release-readiness`; latest app-code commit `6feb459`, with later documentation commits recording build/device evidence. The branch has not been published for review.
- Linear project: [Briefcase iOS](https://linear.app/spacedrift/project/briefcase-ios-efba9794f794), target 10 November 2026, project status In Progress, lead Chirag Kumar.
- [SPA-16 release candidate and handoff](https://linear.app/spacedrift/issue/SPA-16/briefcase-ios-release-candidate-and-handoff) is In Progress, due 10 November. [SPA-13 feature scope](https://linear.app/spacedrift/issue/SPA-13/briefcase-ios-complete-approved-feature-scope) is In Progress, due 3 November; [SPA-14 quality pass](https://linear.app/spacedrift/issue/SPA-14/briefcase-ios-quality-performance-and-defect-pass) is In Progress, due 7 November; [SPA-15 core flows](https://linear.app/spacedrift/issue/SPA-15/briefcase-ios-design-and-core-end-to-end-flows) is In Progress, due 27 October. [SPA-6 repository foundation](https://linear.app/spacedrift/issue/SPA-6/briefcase-ios-repository-and-technical-foundation) and [SPA-7 scope/acceptance](https://linear.app/spacedrift/issue/SPA-7/briefcase-ios-confirm-scope-and-acceptance-criteria) are Done.
- No blocking/related issue dependencies are recorded. SPA-13–SPA-16 each have an audit comment updated on 21 October documenting verified work and remaining blockers. SPA-7 is marked Done, but has no detailed acceptance checklist attached in its issue description or comments; acceptance remains to be confirmed with the product owner.
- [SPA-28, “Prepare reproducible demo and release evidence”](https://linear.app/spacedrift/issue/SPA-28/prepare-reproducible-demo-and-release-evidence) is Done under the **FieldProof Android** project and links the FieldProof repository. It is not evidence for Briefcase iOS and was excluded from this release assessment.

## Checks completed

- Follow-up verification on the release branch (`55a6975`, including `f9e04ea`): generic iOS device and generic iOS Simulator builds both succeed with Xcode when run outside the restricted shell using temporary derived-data/package-cache paths and `CODE_SIGNING_ALLOWED=NO`. They compile and link the app but do not install or launch it.
- A signed device-specific build succeeded with the configured Apple Development identity and existing provisioning profile. It was installed and launched on the paired iPhone 16. The full local synthetic flow was then exercised: client change request on Version 1, consultant creates Version 2, client approves Version 2, the two version-specific local audit events are inspected, and the restricted account is denied access. After force-quit and relaunch, the app returned to Client/Version 1 pending, confirming in-memory state resets on termination. The UI disclosed local-only behavior throughout.
- The primary demo account, project, version, review-status, revision, decision, feedback, and audit controls now expose stable accessibility identifiers. The updated app built, installed, and launched again on iPhone 16. This improves automation/accessibility targeting but is not a substitute for an XCUITest target or workflow execution.
- The tertiary metadata text color was darkened after a contrast check found the former color below WCAG AA; the revised color computes to at least 4.60:1 against the app's paper, surface, and muted-card backgrounds. Generic device/Simulator builds passed after the change, and the signed app was installed and visually checked on iPhone 16. This is a color contrast check, not a complete accessibility audit.
- Instruments `App Launch` recording was retried while the iPhone was available in Mirroring, but xctrace again timed out waiting for the device to boot (reported iOS 26.6). No performance trace or profile result is claimed.
- The backend requirements from `backend/requirements.lock` were installed into a temporary Python 3.13 environment and the suite passed again: **12 tests, 0 failures**.

- Before these local edits, `git status --short --branch` showed a clean `main` checkout at the base commit above.
- Xcode project and app Info.plist passed `plutil -lint`; the shared scheme passed `xmllint --noout`.
- Swift core suite: **13 tests passed, 0 failed** with SwiftPM's supported per-command `--disable-sandbox` flag.
- Current app and core sources passed an `arm64-apple-ios16.0` type-check against the installed iOS 27 SDK. The standalone check does not link or package the app.
- Core package resolution succeeded (no external package dependencies), and the core package built for `arm64-apple-ios16.0`.
- Backend suite: **12 tests passed, 0 failed** using SQLite fixtures and synthetic identities.
- Documented Uvicorn startup succeeded locally. `/health/live` returned HTTP 200 `{"status":"alive"}`. `/health/ready` returned HTTP 503 `{"detail":"database_not_configured"}` because this host has no configured database URL.
- GitHub Actions are green for the committed base SHA: [iOS run 38774565079](https://github.com/spacedrift-in/briefcase-ios/actions/runs/38774565079) built the app for generic iOS and ran the Swift core tests; [Backend run 38774564990](https://github.com/spacedrift-in/briefcase-ios/actions/runs/38774564990) installed `backend/requirements.lock` and ran pytest. Both completed successfully on 15 October 2026. No CI run or PR exists yet for this local branch. Publishing the branch was blocked by automatic approval review pending explicit authorization.

## Remaining release gates

- The ordinary restricted-shell Xcode device build still stops during SwiftPM package resolution while writing the manifest diagnostic under `~/Library/Caches/org.swift.swiftpm` (`Operation not permitted`). Running the same generic-device build outside that shell succeeded; no security setting was weakened. Simulator builds and local installation/launch remain unverified.
- CoreSimulatorService is unavailable and no simulator runtime can be discovered. Interactive approval and termination/relaunch walkthrough is now verified on iPhone 16, but formal VoiceOver/Dynamic Type/contrast/usability review and Instruments performance/crash profiling remain incomplete. The app target does not yet have an XCUITest target.
- The app is a synthetic, in-memory demo. It resets decisions after termination, does not upload file bytes, authenticate users, load protected project data, or create authoritative server audit records. Its UI labels the audit as local and says mutations are not sent to a server. The main local walkthrough has been exercised; production backend behavior remains outside the demo.
- Backend tests use SQLite and synthetic identity claims. A live OIDC provider, PostgreSQL migration/transaction behavior, and deployment readiness remain unverified. No production API integration or load testing is claimed.
- The iOS 16 deployment target, iPhone/iPad target family, scheme, and launch configuration are present. The iPad orientation setting now allows portrait, upside-down portrait, and both landscape orientations in Debug and Release to address the previously recorded warning; this project-setting edit has only passed plist syntax validation so far. Runtime orientation behavior, physical-device usability, and accessibility remain unverified.

## Demo

Follow [demo.md](demo.md) for the synthetic sequence: client requests changes on Version 1, consultant creates metadata-only Version 2, client reviews and approves Version 2, local activity is inspected, and a restricted fixture is denied. The screen labels local actions; do not present them as server-confirmed approvals or durable audit history.

Setup and command details are in [setup.md](setup.md) and [testing.md](testing.md). Do not call this a fully accepted release candidate until the interactive/device gates are completed and the authorized product owner records acceptance against the agreed criteria.
