# Local development

Use Bun for both applications. The repository includes `bun.lock`; do not
reintroduce an npm lockfile for normal application work.

## Prerequisites

- Bun and a Cloudflare account authenticated for Wrangler commands.
- A local CMS database initialized through the SonicJS migrations.
- A `BETTER_AUTH_SECRET` for each environment that serves authentication. Keep
  the real value in a secret manager or Wrangler secret; never commit it.

## Run the CMS

From the `kerryhatcher-com` repository root:

```sh
bun install
bun run dev
```

The relevant CMS configuration is `wrangler.toml` in the application repository.
It declares the `DB` D1 binding, `MEDIA_BUCKET` R2 binding, CORS origins, and
the `sjs.kerryhatcher.com` custom domain.

Before using a new D1 database, examine and apply the pending migrations. Use
the binding name rather than copying a database ID into commands:

```sh
npx wrangler d1 migrations list DB
npx wrangler d1 migrations apply DB
```

Use `--remote` only when intentionally changing the deployed database:

```sh
npx wrangler d1 migrations list DB --remote
npx wrangler d1 migrations apply DB --remote
```

Do not wrap remote D1 migration or seed work in `BEGIN`/`COMMIT`; Wrangler’s
remote D1 command path does not accept transaction control statements. Prefer
the migration system or independent idempotent statements.

## Run the Astro frontend

From `frontend/`:

```sh
bun install
cp .dev.vars.example .dev.vars
bun run dev
```

Set the development `CMS_ORIGIN` in `.dev.vars` to the CMS endpoint you are
testing, commonly:

```dotenv
CMS_ORIGIN=http://localhost:8787
```

`frontend/src/lib/cms.ts` is the one place that assembles the public collection
request. Keep content reads server-side unless a user interaction truly needs
client-side fetching.

## Test the complete flow

1. Open the CMS admin at `http://localhost:8787/admin` and sign in with a
   locally provisioned administrator.
2. Create or publish a `blog_post` with a title, unique slug, author, and valid
   content JSON.
3. Request the public CMS endpoint directly:

   ```sh
   curl 'http://localhost:8787/api/collections/blog_post/content?limit=100'
   ```

4. Open the Astro local site. The index should display the post and the post
   URL should resolve by slug.
5. Build before deployment:

   ```sh
   bun run build
   ```

If the Astro site unexpectedly shows old content, first verify the CMS response
and publication status. The frontend only receives the public collection
result, not draft content.

## Local configuration boundaries

- `.dev.vars` is a local runtime override and must remain uncommitted.
- `frontend/wrangler.toml` supplies the deployed `CMS_ORIGIN` value.
- `wrangler.toml` at the repository root configures the CMS; it is unrelated to
  the Astro Worker’s generated deploy configuration.

## Sources

- [SonicJS quick start](https://sonicjs.com/quickstart)
- [SonicJS database documentation](https://sonicjs.com/database)
- [Cloudflare D1 Wrangler commands](https://developers.cloudflare.com/workers/wrangler/commands/d1/)
- [Astro environment variables](https://docs.astro.build/en/guides/environment-variables/)
