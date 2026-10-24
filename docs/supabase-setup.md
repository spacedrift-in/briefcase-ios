# Supabase setup for Briefcase iOS

## Created project

- Organization: `Briefcase iOS` (Free)
- Project: `Briefcase iOS`
- Project ref: `vetivgesigevfcolqpca`
- Project URL: `https://vetivgesigevfcolqpca.supabase.co`
- Region: South Asia (Mumbai), `ap-south-1`
- Creation settings: Free/Nano; Supabase Data API disabled; automatic RLS enabled.

On 24 October 2026, the dashboard reports the project as **Healthy**. A technical-issue notice remains visible in the dashboard; check the [Supabase status page](https://status.supabase.com/) if project operations fail.

## Database password handoff

The owner set the database password in Supabase and saved it to the ignored local file `backend/.env` through a hidden prompt. The file has owner-only permissions and is gitignored. Do not send the password in chat. The connection URL percent-encodes reserved password characters.

The connection uses the project database user `postgres` and database `postgres`. The direct endpoint is `db.vetivgesigevfcolqpca.supabase.co:5432`; if the eventual backend host is IPv4-only, copy the session-pooler connection string from Supabase's **Connect** panel instead of guessing its pooler host.

## OIDC settings

On 24 October 2026, a 2048-bit RSA standby signing key was created and rotated to current. Supabase Auth now signs new tokens with RS256. The former ECC (ES256) and legacy HS256 keys remain listed as previously used keys to validate non-expired tokens; do not revoke them until their tokens have expired. The project's JWKS endpoint was checked and returned both the current RSA public key and the former ECC public key.

Use these public verification settings in the backend environment:

```dotenv
OIDC_ISSUER=https://vetivgesigevfcolqpca.supabase.co/auth/v1
OIDC_AUDIENCE=authenticated
OIDC_JWKS_URL=https://vetivgesigevfcolqpca.supabase.co/auth/v1/.well-known/jwks.json
```

These are URLs/claim values, not passwords. The backend verifier already uses `PyJWKClient` against the configured JWKS URL and pins `RS256`. The iOS app still needs a native sign-in/session implementation, and the FastAPI API needs a reachable deployment URL. Neither is configured by creating the Supabase project.

## Private file storage

The private bucket `deliverables` was created. It accepts PDF, JPEG, PNG, and HEIC files up to 25 MB. It is not public and has no client policies. The current backend has no upload/download endpoints or Supabase Storage adapter, so do not upload real deliverables yet. Keep the bucket private and do not put any Supabase secret/service key in the iOS app. Before enabling uploads, implement server-side authorization and enforce the same file size and media-type restrictions.

## Database initialization

On 24 October 2026, the Alembic migrations were applied to Supabase through revision `a41047ef1b6c` (`head`), and the backend readiness check returned `{"status":"ready"}`. The project has no application workspace memberships or sample records yet; real users will not see projects until authorized membership rows are provisioned.
