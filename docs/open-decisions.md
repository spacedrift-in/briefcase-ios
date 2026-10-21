# Open decisions and blockers

No external product or infrastructure assumptions have been treated as approved. Decisions below need an owner and answer before the affected design is finalized.

| Priority | Question | Why it matters | Safe provisional recommendation |
|---|---|---|---|
| Blocker | Which workspace roles may upload, request changes, approve, and export history? Can a user hold multiple roles? | Authorization matrix and demo journey | Workspace Owner/Consultant can upload; assigned Client Reviewer can comment/request changes/approve; verify with product owner. |
| Blocker | May a version have one final approval or multiple independent approvals? What are the allowed transitions/reopen rules? | Schema, state machine, idempotency | One reviewer decision per version for initial slice; decisions immutable, new versions get new pending state. |
| Blocker | Which document types and maximum sizes are needed for the first milestone? Is annotation limited to comments? | Viewer, upload, storage, and security scope | PDF/images with version comments only, contingent on confirmation. |
| Resolved | Which minimum iOS version? | Deployment target and testing destinations | User selected iOS 16+. iPhone first remains provisional; confirm iPad support/device audience. |
| Blocker | Which authentication provider/session model is approved? Are demo users locally seeded or externally provisioned? | Credential lifecycle and server setup | Short-lived access tokens with refresh/session revocation; provider selection remains open. |
| Blocker | Which identity, PostgreSQL, and private file-storage services are already available? | Integration adapters, deployment, and access control | User prefers existing services; provider names/access are not yet known. |
| Important | Does the existing OIDC provider issue RS256-signed access tokens for the API audience? | Token validation algorithm and JWKS behavior | Current verifier allowlists RS256; confirm against selected provider before integration.
| Important | Which project roles may export audit history? | Data access and privacy policy | Current API allows any active project member; needs confirmation before release. |
| Important | What are audit retention/export format requirements and who can export? | Privacy, storage, and audit scope | Workspace-authorized JSON/CSV export; retention needs owner decision. |
| Important | What expected dataset sizes and measurable response targets are acceptable? | Performance test design | Establish during milestone 1; no numbers invented. |
| Important | Who is implementation owner and who reviews authorization/schema changes? | Delivery accountability | Not provided. |
| Resolved for tracking | Is Linear tracking required and can project access be enabled? | Project issue and milestone tracking | Briefcase iOS is tracked as project `P-SPA-2`; see the [release-candidate status](release-candidate-status.md). No issue updates were made during this verification. |

## Environment blockers

- CoreSimulatorService is unavailable and no simulator runtime could be discovered.
- Docker daemon is unavailable; PostgreSQL is not otherwise verified.
- The initial pasted snapshot has no Git metadata; the actual checkout is now `main` at `cec8db2`, as recorded in [release-candidate status](release-candidate-status.md).
- Linear project and issue details were accessible during the 2026-10-21 release-candidate review; no issue state was changed.
- Local CLI Xcode builds stop at SwiftPM manifest diagnostics with `spacedriftcore.dia` `Operation not permitted`. Hosted iOS CI built the current commit successfully. Physical-device behavior has not been manually verified.

## Current vertical-slice boundary

- The iOS target retains its local in-memory synthetic walkthrough and now uses the core URLSession client for unauthenticated `/health/live` and `/health/ready` checks. Project/timeline reads still need the selected OIDC provider and a real token/session implementation; API status does not claim authenticated access. Core Data remains unwired to the UI.
- The app does not have production sign-in/session restoration or Keychain storage. Provider-neutral client interfaces remain unconnected pending actual issuer, audience, native client configuration, and callback details.
- The backend currently has no file upload or download routes. A secure workflow requires the selected private storage service and server-side authorization design; the consultant revision control currently creates synthetic metadata only.
- CI workflow definitions ran successfully for base commit `cec8db2`; no CI run exists yet for the local review branch. See [release-candidate status](release-candidate-status.md). Hosted CI does not replace interactive or physical-device verification.

These blockers do not establish that external infrastructure is unavailable; they describe only this local session. User direction is to use existing services, not the local demo-service proposal.
