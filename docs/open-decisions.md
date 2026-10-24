# Open decisions and blockers

The following provisional MVP defaults were explicitly approved by the user on 24 October 2026. Provider-specific configuration, deployment access, and remaining policy decisions are still open.

| Priority | Question | Why it matters | Safe provisional recommendation |
|---|---|---|---|
| Resolved (24 Oct) | Which roles upload, comment, and decide? Can a user hold multiple roles? | Authorization matrix and demo journey | Workspace Owner/Consultant can upload; assigned Client Reviewer can comment/request changes/approve. Multi-role assignment remains unspecified and must not be assumed. Export authorization remains an open row below. |
| Resolved (24 Oct) | May a version have one final approval or multiple independent approvals? What are the allowed transitions/reopen rules? | Schema, state machine, idempotency | User approved one reviewer decision per version; decisions are immutable and a new version starts pending. |
| Partial (24 Oct) | Which document types and maximum sizes are needed for the first milestone? Is annotation limited to comments? | Viewer, upload, storage, and security scope | User approved PDF/images with version comments only. Maximum file size is still required before upload can be enabled. |
| Resolved | Which minimum iOS version? | Deployment target and testing destinations | User selected iOS 16+. iPhone first remains provisional; confirm iPad support/device audience. |
| Partial (24 Oct) | Which authentication provider/session model is approved? Are demo users locally seeded or externally provisioned? | Credential lifecycle and server setup | User approved OIDC with RS256 validation. Identity provider, native client ID/callback, and session provisioning/revocation settings remain provider-specific blockers. |
| Partial (24 Oct) | Which identity, PostgreSQL, and private file-storage services are already available? | Integration adapters, deployment, and access control | On 24 Oct, user authorized a free Supabase project; project `vetivgesigevfcolqpca` was created in Mumbai. It is still provisioning during a Supabase management API incident. Database password needs owner reset/handoff; private bucket and RS256 configuration are not yet complete. |
| Resolved (24 Oct) | Does the existing OIDC provider issue RS256-signed access tokens for the API audience? | Token validation algorithm and JWKS behavior | RS256 OIDC is the approved contract. The selected provider must still be checked for issuer, audience, JWKS URL, and claims. |
| Important | Which project roles may export audit history? | Data access and privacy policy | Current API allows any active project member; needs confirmation before release. |
| Important | What are audit retention/export format requirements and who can export? | Privacy, storage, and audit scope | Workspace-authorized JSON/CSV export; retention needs owner decision. |
| Important | What expected dataset sizes and measurable response targets are acceptable? | Performance test design | Establish during milestone 1; no numbers invented. |
| Important | Who is implementation owner and who reviews authorization/schema changes? | Delivery accountability | Not provided. |
| Resolved | Is Linear tracking required and can project access be enabled? | Project issue and milestone tracking | Briefcase iOS is tracked in Linear; see the [release-candidate status](release-candidate-status.md). SPA-6 and SPA-7 are Done; SPA-13–SPA-16 remain In Progress pending completion and verification. |

## Environment blockers

- CoreSimulatorService is unavailable and no simulator runtime could be discovered.
- Docker daemon is unavailable; PostgreSQL is not otherwise verified.
- The initial pasted snapshot has no Git metadata; the actual repository checkout is `codex/briefcase-release-readiness`, linked to PR #1; see [release-candidate status](release-candidate-status.md).
- Linear is connected. SPA-15 is Done (24 Oct); SPA-13, SPA-14, and SPA-16 remain In Progress with their outstanding gates recorded in Linear.
- Xcode generic device and Simulator builds and a signed iPhone 16 walkthrough succeeded earlier outside the restricted shell. CoreSimulatorService is currently unavailable. Four hosted PR checks passed on head `63debf9`; CI must rerun for the current uncommitted changes. Formal accessibility/performance profiling and PR review are outstanding.

## Current vertical-slice boundary

- The iOS target retains its local in-memory synthetic walkthrough and now uses the core URLSession client for unauthenticated `/health/live` and `/health/ready` checks. Project/timeline reads still need the selected OIDC provider and a real token/session implementation; API status does not claim authenticated access. Core Data remains unwired to the UI.
- The app does not have production sign-in/session restoration or Keychain storage. Provider-neutral client interfaces remain unconnected pending actual issuer, audience, native client configuration, and callback details.
- The backend still has no file upload or download routes. A secure workflow requires a selected private storage provider and configured maximum size; the consultant demo revision control still creates synthetic metadata only. Project/version detail and version-comment routes are implemented.
- User-approved defaults (24 Oct): PostgreSQL, private object storage, OIDC/RS256, Workspace Owner/Consultant upload, Client Reviewer comments and decisions, one final decision per immutable version, and PDF/images with version comments. Supabase was selected and a free project created; the generated database password was not captured for local configuration and must be reset by the owner. See [Supabase setup](supabase-setup.md).
- CI workflow definitions passed for base commit `cec8db2`, PR head `63debf9`, and the API/comment update `8e2408d`; all four checks passed on `8e2408d`. See [release-candidate status](release-candidate-status.md). Hosted CI does not replace interactive or physical-device verification.

These blockers do not establish that external infrastructure is unavailable; they describe only this local session. User direction is to use existing services, not the local demo-service proposal.
