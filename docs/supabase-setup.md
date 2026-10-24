# Supabase setup for Briefcase iOS

## Created project

- Organization: `Briefcase iOS` (Free)
- Project: `Briefcase iOS`
- Project ref: `vetivgesigevfcolqpca`
- Project URL: `https://vetivgesigevfcolqpca.supabase.co`
- Region: South Asia (Mumbai), `ap-south-1`
- Creation settings: Free/Nano; Supabase Data API disabled; automatic RLS enabled.

The dashboard currently reports the project as **Coming up** and shows an active technical-issue notice. Storage and Auth settings could not be applied while the project is provisioning. Check the [Supabase status page](https://status.supabase.com/) before retrying.

## Database password handoff

The database password generated during project creation was not recoverable from the browser after provisioning. Supabase does not show the existing password again. The owner must set/reset it directly in **Project Settings → Database**. Do not send it in chat. Store the replacement in the ignored local file `backend/.env` and URL-encode reserved characters in `DATABASE_URL`.

The connection uses the project database user `postgres` and database `postgres`. The direct endpoint is `db.vetivgesigevfcolqpca.supabase.co:5432`; if the eventual backend host is IPv4-only, copy the session-pooler connection string from Supabase's **Connect** panel instead of guessing its pooler host.

## OIDC settings

After the project is ready, configure Supabase Auth to use an asymmetric RS256 signing key. Then use these public verification settings in the backend's private environment:

```dotenv
OIDC_ISSUER=https://vetivgesigevfcolqpca.supabase.co/auth/v1
OIDC_AUDIENCE=authenticated
OIDC_JWKS_URL=https://vetivgesigevfcolqpca.supabase.co/auth/v1/.well-known/jwks.json
```

These are URLs/claim values, not passwords. The iOS app still needs a native sign-in/session implementation, and the FastAPI API needs a reachable deployment URL. Neither is configured by creating the Supabase project.

## Private file storage

Create a private bucket named `deliverables` after provisioning completes. The current backend has no upload/download endpoints or Supabase Storage adapter, so do not upload real deliverables yet. Keep the bucket private and do not put any Supabase secret/service key in the iOS app. The maximum file size remains unset in the app/backend; choose and enforce it before enabling uploads.

## Database initialization

Once the owner has set the password and the project is healthy, configure `backend/.env`, install the locked backend dependencies, apply Alembic migrations, and check `/health/ready`. The project has no application workspace memberships or sample records yet; real users will not see projects until authorized membership rows are provisioned.
