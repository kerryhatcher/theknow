# Authentication and RBAC

SonicJS uses Better Auth for identity and a document-backed RBAC model for
authorization. Keep those concerns distinct when diagnosing login problems.

## Required bootstrap order

1. Apply SonicJS database migrations.
2. Set a strong `BETTER_AUTH_SECRET` on the intended CMS Worker environment.
3. Create the first user through the supported bootstrap/admin path.
4. Assign a SonicJS RBAC role using the application service or admin UI.
5. Sign in in a fresh browser session and verify `/admin/dashboard`.

`wrangler secret list` only shows that a secret name exists. It is not proof
that the deployed Worker is reading the target environment’s binding. Always
verify a real sign-in and protected page after changing authentication secrets.

## Why “login succeeded” can still lead to denial

The legacy `auth_user.role` value is not the final authorization decision for
the admin UI. SonicJS bootstraps RBAC roles and verbs as documents and evaluates
assignments from the RBAC user-role model. Thus a user can have a valid session
but still receive “You do not have permission to access this area.”

The intended path is:

```text
authenticated user
  -> RBAC bootstrap creates role/verb documents
  -> RbacService assignment associates user ID to role ID
  -> permission check for the requested admin route
```

For code-level recovery or automation, call the SonicJS RBAC service after the
system seed has run. In this implementation, inspect the RBAC calls in the
application and SonicJS source before writing direct D1 records. Direct SQL can
help a constrained recovery, but it bypasses validation and can create an
account that authenticates without usable permissions.

## Safe operational rules

- Never put a password, session token, database ID, or secret value in source
  code, issue trackers, or this wiki.
- Generate authentication secrets with a cryptographically secure generator and
  upload them with `wrangler secret put`.
- Scope every Wrangler secret command with `--env=""` or the specific named
  environment; otherwise confirm the deploy target first.
- Use the admin UI or service layer for users and roles. Treat direct D1 edits
  as an audited, emergency recovery step.
- After changing an account or role, sign out and sign in again to avoid testing
  an old session.

## Incident checklist

| Symptom | Likely layer | First check |
| --- | --- | --- |
| “Login failed” | identity, user record, or authentication secret | migrations applied, intended secret bound, account data |
| Login redirects then fails | session/cookie or host configuration | browser cookies, custom domain, fresh session |
| “No permission” after login | RBAC assignment | role documents and user-role assignment, not only `auth_user.role` |
| Works locally but not deployed | different Wrangler target or remote DB | `--env`, remote migrations, deployed binding names |

## Relevant implementation references

- `src/index.ts` — SonicJS application creation and startup.
- `src/collections/` — collection registration that occurs during bootstrap.
- SonicJS RBAC service and bootstrap code in the installed `@sonicjs-cms/core`
  package — use this as the current source of truth for supported APIs.

## Sources

- [SonicJS API reference](https://sonicjs.com/api)
- [SonicJS configuration reference](https://sonicjs.com/configuration)
- [Cloudflare: secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Better Auth documentation](https://www.better-auth.com/docs)

