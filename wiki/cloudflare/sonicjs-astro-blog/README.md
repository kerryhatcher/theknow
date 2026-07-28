# SonicJS CMS and Astro blog on Cloudflare

This guide documents the test blog environment built from the
`kerryhatcher-com` SonicJS project and its separate `frontend/` Astro project.
It is a working pattern for a small headless CMS: SonicJS owns administration,
content, authentication, D1, and media; Astro owns the public reading
experience. Both applications are deployed as Cloudflare Workers.

The known CMS hostname is `https://sjs.kerryhatcher.com`. The Astro frontend is
currently available at its `workers.dev` URL. Keep a future public frontend
hostname separate from the CMS hostname, and do not change `www.kerryhatcher.com`
as part of work on this test environment.

## Contents

- [Local development](local-development.md) — install with Bun, configure the
  two applications, and run them together
- [Deployments and domains](deployment.md) — build, deploy, environments,
  custom domains, and rollback-oriented checks
- [Authentication and RBAC](authentication-and-rbac.md) — initial admin setup,
  the document-backed role model, and safe recovery guidance
- [Content and API reference](content-and-api.md) — the blog collection,
  public API contract, and how the Astro app consumes it
- [Troubleshooting](troubleshooting.md) — the failure modes encountered while
  standing up this environment
- [Official source material](official-references.md) — vendor documentation and
  the relevant source files in this implementation

## Architecture

```text
Readers
  |
  v
Astro blog Worker (frontend/)
  | server-side GET using CMS_ORIGIN
  v
SonicJS CMS Worker (sjs.kerryhatcher.com)
  |                       |
  v                       v
Cloudflare D1          Cloudflare R2
content, users, RBAC   media objects

Editors --> SonicJS /admin --> authenticated CMS APIs --> D1/R2
```

### Runtime boundaries

| Component | Responsibility | Configuration source |
| --- | --- | --- |
| SonicJS CMS Worker | Admin UI, collection schemas, API, Better Auth, RBAC, D1 and R2 bindings | `wrangler.toml`, `src/index.ts`, `src/collections/` |
| D1 database | SonicJS migrations plus content, users, sessions, and RBAC documents | `migrations/`, `wrangler.toml` D1 binding |
| R2 bucket | Uploads and media storage | `wrangler.toml` R2 binding |
| Astro Worker | Public blog index and post routes; reads published CMS content | `frontend/astro.config.mjs`, `frontend/src/lib/cms.ts` |
| `CMS_ORIGIN` | Server-side bridge from Astro to the CMS public API | `frontend/wrangler.toml`; local override in `frontend/.dev.vars` |

There is intentionally no browser-to-CMS dependency for initial page rendering:
Astro fetches content on the server. That avoids exposing an admin credential
and keeps the public site’s data dependency explicit. The CMS public collection
endpoint still needs to be treated as a public contract: only published content
belongs there.

## Quick start

From the CMS repository root:

```sh
bun install
bun run dev
```

In a second terminal, run the public site:

```sh
cd frontend
bun install
cp .dev.vars.example .dev.vars
bun run dev
```

The Astro development server should point `CMS_ORIGIN` at the local CMS for
end-to-end work. See [Local development](local-development.md) for ports,
migrations, and verification steps.

## Design decisions and constraints

- **Two deployables, two names.** The CMS and public site are separate Workers;
  deploying either one should not replace the other or alter `www`.
- **Code-defined collections.** SonicJS reads collection definitions during
  bootstrap. The `blog_post` schema is source-controlled; its content records
  live in the shared documents model rather than in a bespoke table.
- **D1 is initialized before login.** A fresh remote database must receive the
  SonicJS migrations before an account or CMS request can work.
- **Roles are not the user’s `role` text field.** SonicJS authorization is
  document-backed. An `auth_user` row marked `admin` alone does not grant the
  permissions used by `/admin`.
- **Default and named Wrangler environments are distinct.** In this project the
  usable test bindings were configured on the top-level/default environment.
  Do not deploy `env.production` until it has its own required bindings,
  variables, migrations, and secrets.

## Source documents

- [SonicJS: collections](https://sonicjs.com/collections)
- [SonicJS: REST API reference](https://sonicjs.com/api)
- [SonicJS: D1 database deep dive](https://sonicjs.com/blog/sonicjs-d1-database-deep-dive)
- [Astro: deploy to Cloudflare](https://docs.astro.build/en/guides/deploy/cloudflare/)
- [Cloudflare: Wrangler configuration](https://developers.cloudflare.com/workers/wrangler/configuration/)
- [Cloudflare: D1](https://developers.cloudflare.com/workers/wrangler/commands/d1/)

