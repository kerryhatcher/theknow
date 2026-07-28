# Troubleshooting

Work from the outside in: identify the Worker hostname, verify its deployed
configuration, then verify the remote dependency it uses. The CMS and frontend
are separate Workers, so a successful frontend deploy says nothing about CMS
authentication and vice versa.

## Wrangler warns about multiple environments

**Symptom:** `wrangler deploy` warns that multiple environments are defined.

**Cause:** The configuration contains both a top-level environment and named
environment sections. The selected bindings may not be the ones intended.

**Resolution:** Be explicit. This test CMS is deployed with:

```sh
npx wrangler deploy --env=""
```

For a named environment, first define every required variable, D1/R2 binding,
and secret for that exact environment. Deploying the wrong environment can look
like a login, CORS, or missing-data failure.

## Login fails after the first deployment

Check, in order:

1. Remote migrations exist and are applied to the intended D1 binding.
2. `BETTER_AUTH_SECRET` exists on the same Wrangler environment being deployed.
3. The user and account records were created by a supported path.
4. You are testing the deployed CMS hostname, not the Astro public Worker.
5. A fresh browser session has no stale cookies.

## Login works but `/admin` says access is denied

The account has authenticated but lacks a valid SonicJS RBAC assignment. Follow
the [Authentication and RBAC](authentication-and-rbac.md) guide. Do not assume
changing only an `auth_user.role` column will satisfy the document-backed
authorization check.

## Custom domain is not ready

**Symptom:** The Worker deploy succeeds but the custom hostname does not answer
immediately.

**Resolution:** Confirm the custom-domain route is in the configuration, then
allow Cloudflare to provision the hostname and certificate. Check the Worker’s
custom domain status in Cloudflare before changing unrelated DNS records. A
separate `workers.dev` URL is useful for confirming the Worker itself is live.

## Blog index is empty

1. Request the CMS endpoint directly with `curl`.
2. Confirm posts are `published`, not draft or archived.
3. Check the Astro Worker’s `CMS_ORIGIN` points at the intended CMS hostname.
4. Confirm the collection name is `blog_post` (underscore included).
5. Rebuild/redeploy the Astro Worker after config changes.

## Astro deployment cannot find a Worker entry point

The Cloudflare adapter produces generated deployment configuration during the
Astro build. Use the frontend deploy script, which deploys
`dist/server/wrangler.json`, rather than adding a pre-build `main` reference to
a guessed output path.

## API creation returns JSON parse errors

Validate the request body before sending it. Rich content JSON is easy to break
when quoted inline in a shell. Generate request bodies with `JSON.stringify` or
use a JSON file/tool that validates syntax, then ensure required collection
fields are present.

## Sources

- [Cloudflare: Wrangler configuration and environments](https://developers.cloudflare.com/workers/wrangler/configuration/)
- [Cloudflare: custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
- [Astro: deploy to Cloudflare](https://docs.astro.build/en/guides/deploy/cloudflare/)
- [SonicJS API reference](https://sonicjs.com/api)

