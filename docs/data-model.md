# Data model proposal

Conceptual model only; no schema or migration exists yet.

| Entity | Key fields and relationships |
|---|---|
| User | Opaque ID, authentication subject, status. No passwords stored in demo fixtures. |
| Workspace | Opaque ID, name. |
| Workspace membership | Workspace ID, OIDC subject, active flag; unique subject/workspace pair. |
| Project membership | Project ID, OIDC subject, role, active flag; unique subject/project pair. |
| Project | Workspace ID, name, summary, status, timestamps. |
| Project access | Project ID, membership/user ID, permission scope if roles alone are insufficient. |
| Deliverable | Project ID, title, description, current version pointer. |
| Deliverable version | Immutable ID, deliverable ID, monotonically ordered version number, storage object key, media type, byte size, checksum, author ID, server creation time. |
| Review decision | Immutable ID, version ID, actor ID, decision type, required comment for change request, server timestamp, idempotency key. |
| Audit event | Immutable event ID, workspace/project IDs, actor ID, event type, target IDs, server timestamp, safe metadata. |

Approval state is derived per version from its decision history/current review projection. A version must not be mutated into a different version, and approval of one version never changes another version's status. Database transaction and uniqueness constraints must prevent duplicate idempotency keys and partial decision/audit writes.

Implemented backend currently has separate `WorkspaceMembership` and project-scoped `ProjectMembership` (subject, role, active), plus workspaces, projects, deliverables, versions, decisions, and audit events. It does not yet have a separate user profile row. Exact constraints, retention, deletion semantics, and whether multiple reviewers are required remain open. Do not store file contents in the relational database by default.
