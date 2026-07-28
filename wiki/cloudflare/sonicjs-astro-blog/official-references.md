# Official source material

Use the application source to answer “what does this deployment do today?” and
the official documentation to answer “what does this platform guarantee and how
should it be operated?” This separation avoids turning a generic vendor example
into an incorrect claim about the deployed system.

## Implementation source map

| Concern | Primary local source |
| --- | --- |
| CMS Worker bindings, default deploy target, custom domain | `wrangler.toml` |
| CMS bootstrap and route registration | `src/index.ts` |
| Blog schema and required fields | `src/collections/blog-posts.collection.ts` |
| D1 schema evolution | `migrations/0001_core.sql`, `migrations/0002_documents.sql` |
| Astro Worker build mode and adapter | `frontend/astro.config.mjs` |
| Astro deployed CMS origin | `frontend/wrangler.toml` |
| CMS fetch and response normalization | `frontend/src/lib/cms.ts` |
| Blog index and post route | `frontend/src/pages/index.astro`, `frontend/src/pages/posts/[slug].astro` |
| Bun build/deploy commands | `package.json`, `frontend/package.json` |

Read these files before changing an endpoint, role model, deploy target, or
domain. They are more authoritative for this instance than broad tutorials.

## SonicJS

- [Quick start](https://sonicjs.com/quickstart) — baseline project and admin
  workflow.
- [Collections](https://sonicjs.com/collections) — TypeScript schemas,
  registration, validation, admin UI behavior, and generated REST endpoints.
- [REST API reference](https://sonicjs.com/api) — API explorer, content
  operations, pagination, and authentication expectations. Confirm exact
  deployed routes against the local implementation because SonicJS APIs evolve.
- [Database documentation](https://sonicjs.com/database) — database model and
  supported database operations.
- [SonicJS D1 database deep dive](https://sonicjs.com/blog/sonicjs-d1-database-deep-dive)
  — D1-specific architecture context.
- [SonicJS source repository](https://github.com/SonicJs-Org/sonicjs) — use the
  installed package version and its source for framework internals, particularly
  auth and RBAC services.

## Astro

- [Deploy to Cloudflare](https://docs.astro.build/en/guides/deploy/cloudflare/)
  — Workers deployment, `@astrojs/cloudflare`, local preview, and runtime
  caveats.
- [Cloudflare adapter guide](https://docs.astro.build/en/guides/integrations-guide/cloudflare/)
  — adapter behavior and environment build considerations.
- [Environment variables](https://docs.astro.build/en/guides/environment-variables/)
  — server/client exposure and local environment files.
- [Routing](https://docs.astro.build/en/core-concepts/routing/) — file-based and
  dynamic route behavior used by `[slug].astro`.
- [On-demand rendering](https://docs.astro.build/en/guides/on-demand-rendering/)
  — server-rendered page behavior and adapter requirements.

## Cloudflare

- [Wrangler configuration](https://developers.cloudflare.com/workers/wrangler/configuration/)
  — configuration formats, bindings, compatibility dates, and deployment
  settings.
- [Wrangler environments](https://developers.cloudflare.com/workers/wrangler/configuration/environments/)
  — default vs named environments and non-inheritable settings.
- [Custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
  — Worker custom-domain lifecycle, DNS, and certificates.
- [Secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
  — writing and reading Worker secrets safely.
- [D1 commands](https://developers.cloudflare.com/workers/wrangler/commands/d1/)
  — migrations, remote commands, and D1 administration.
- [R2 bindings](https://developers.cloudflare.com/r2/api/workers/workers-api-usage/)
  — using R2 from a Worker binding.
- [Worker commands](https://developers.cloudflare.com/workers/wrangler/commands/workers/)
  — deploy, version, and deployment administration.

## Better Auth

- [Better Auth documentation](https://www.better-auth.com/docs) — framework
  behavior and configuration. Match any integration advice to the version
  installed by SonicJS before applying it.

