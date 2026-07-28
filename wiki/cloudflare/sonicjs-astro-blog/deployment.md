# Deployments and domains

This environment has two independently deployed Workers. Treat their deploy
commands and domain configuration as separate operations.

| Deployment | Directory | Purpose | Current domain posture |
| --- | --- | --- | --- |
| SonicJS CMS | repository root | admin UI, APIs, D1/R2 integrations | custom domain: `sjs.kerryhatcher.com` |
| Astro frontend | `frontend/` | public blog pages | deployed to its Worker URL; custom public hostname can be added later |

## Deploy the CMS Worker

The root deploy script explicitly targets the top-level/default Wrangler
environment:

```sh
bun run deploy
```

Equivalent explicit form:

```sh
npx wrangler deploy --env=""
```

The empty environment name is deliberate. Wrangler warns when a configuration
contains both top-level bindings and named environments because the target can
be ambiguous. This CMS test environment uses the top-level bindings. Do not use
`--env production` merely because the section exists: named environments do not
inherit all bindings and secrets automatically.

Before first deployment to a new environment:

1. Check `wrangler.toml` has the intended D1 and R2 binding names.
2. Apply remote D1 migrations for that database.
3. Put the authentication secret in the exact target environment:

   ```sh
   npx wrangler secret put BETTER_AUTH_SECRET --env=""
   ```

4. Deploy and confirm the reported Worker URL and version ID.
5. Verify both the public collection endpoint and `/admin` in a fresh browser
   session.

## Deploy the Astro Worker

From `frontend/`:

```sh
bun run deploy
```

This script runs the Astro build and deploys the generated
`dist/server/wrangler.json`. That generated file is important: the Cloudflare
adapter creates the Worker entry point and assets configuration. Do not point a
hand-written pre-build config at a guessed `dist/_worker.js/index.js`; it can
diverge from the adapter output.

Confirm the deployment’s Worker URL renders published posts before assigning a
custom hostname.

## Custom domains

The CMS uses Wrangler’s custom-domain route form:

```toml
routes = [
  { pattern = "sjs.kerryhatcher.com", custom_domain = true }
]
```

This delegates DNS and certificate handling for that exact hostname to
Cloudflare. It is different from attaching a Worker route to a pre-existing
proxied DNS record. Use the custom-domain mechanism for a new, dedicated
hostname and wait for Cloudflare to provision it before treating DNS as broken.

For the public Astro site, decide its own hostname first (for example a test
subdomain). Add a route only to the Astro Worker; never repoint
`www.kerryhatcher.com` as a shortcut for testing.

## Post-deploy checks

```sh
curl --fail-with-body 'https://sjs.kerryhatcher.com/api/collections/blog_post/content?limit=100'
curl --fail-with-body 'https://YOUR-ASTRO-WORKER.workers.dev/'
```

Then manually verify:

- a public post appears on the index and its slug route;
- the CMS sign-in works in a new browser session;
- an authenticated administrator reaches `/admin/dashboard` rather than an
  access-denied page;
- `www.kerryhatcher.com` was not modified.

## Rollback posture

Cloudflare records Worker versions at deploy time. If an application deploy is
bad, use the dashboard or Wrangler’s Worker version/deployment controls to
return traffic to a known-good version. Database migrations are not automatically
reversible; design future migrations as forward-compatible and take an export or
backup plan before destructive schema changes.

## Sources

- [Astro: deploy to Cloudflare Workers](https://docs.astro.build/en/guides/deploy/cloudflare/)
- [Cloudflare: Wrangler environments](https://developers.cloudflare.com/workers/wrangler/configuration/environments/)
- [Cloudflare: custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
- [Cloudflare: secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Cloudflare: Worker commands](https://developers.cloudflare.com/workers/wrangler/commands/workers/)

