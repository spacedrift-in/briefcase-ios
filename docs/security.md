# Security principles

The following are required design constraints for production; implementation is partial and the remaining boundaries are listed below.

- Authenticate every protected request on the server. Enforce active workspace membership and project permissions for every read, mutation, download, and export.
- Scope database queries to authorized workspace/project IDs before returning content. Return a non-disclosing denial for inaccessible IDs.
- Keep tokens in iOS Keychain. Never embed service credentials or long-lived secrets in the app bundle, source, logs, fixtures, or screenshots.
- Use private object storage. Authorize downloads server-side and issue short-lived capabilities only after access checks.
- Validate MIME type, file signature, size, checksum, and upload status server-side. Store uploads under unguessable object keys and isolate tenants.
- Commit approval/request-change records and corresponding audit event atomically. Use server timestamps and immutable version references.
- Redact tokens, signed URLs, and sensitive request content from logs. Define audit retention and access policy before release.
- Demo seed operations must require an explicit demo/test environment and must never create production credentials.
- Use TLS for non-local environments; configure secrets through environment/secret manager and never commit `.env` files.

## Implemented backend protections

- OIDC verifier pins `RS256` and validates signature, issuer, audience, expiry, issue time, and subject. The issuer/audience/JWKS URL are required before protected routes can authenticate.
- Project and version endpoints check active workspace membership plus project membership. Inaccessible project/version IDs return a non-disclosing 404 response.
- Only the `client_reviewer` project role may record a decision. An approval/request-change record and its audit event commit in one transaction; unique constraints protect one decision per version and actor-scoped idempotency keys.
- This does not yet secure binary upload/download because those endpoints and the storage adapter are not implemented. Live PostgreSQL readiness and the Supabase RS256 JWKS were checked, but no real user token has been used for an end-to-end protected API request.
