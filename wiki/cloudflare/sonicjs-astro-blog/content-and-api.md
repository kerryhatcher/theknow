# Content and API reference

The public blog uses the SonicJS `blog_post` collection. It is a code-defined
content type, registered during CMS bootstrap, with its records stored in the
shared SonicJS document model.

## Collection source of truth

The collection definition is:

```text
src/collections/blog-posts.collection.ts
```

Update the schema there, then restart local development or deploy the CMS so
SonicJS can register the change. The admin collections screen is a view of
registered code definitions, not a schema editor.

At minimum, a post should have:

| Field | Purpose |
| --- | --- |
| `title` | Reader-facing headline |
| `slug` | Unique URL segment used by the Astro route |
| `status` | Publication state; only publish intentionally |
| `data.content` | Lexical-compatible JSON content required by this collection |
| `data.author` | Required attribution field |

## Public collection endpoint

The deployed frontend uses this endpoint:

```http
GET /api/collections/blog_post/content?limit=100
```

Example:

```sh
curl 'https://sjs.kerryhatcher.com/api/collections/blog_post/content?limit=100'
```

The response follows the `{ data, meta }` envelope. Each item includes the
content root ID, title, slug, status, collection ID, data payload, and created/
updated timestamps. Public requests return published content only.

Do not substitute an outdated generic endpoint from an old README without
testing it against the deployed CMS. The collection content endpoint above is
the route used and verified by this implementation.

## Astro integration

`frontend/src/lib/cms.ts` performs the CMS fetch. It reads `CMS_ORIGIN`, calls
the collection endpoint, normalizes the response, and sorts posts by the
available publication/update timestamps.

`frontend/src/pages/index.astro` renders the collection listing. The dynamic
route `frontend/src/pages/posts/[slug].astro` loads the collection and finds the
matching item by its `slug`.

The generic endpoint `GET /api/blog_post/:id` takes the document root ID, not a
slug. Keep the slug-to-post lookup explicit until the CMS exposes a verified
slug lookup route that meets the frontend’s needs.

## Create and publish content

Use `/admin` for editorial work. For API automation, first authenticate using a
supported account and use a JSON serializer rather than hand-quoting a rich
content payload. A malformed JSON body results in a request failure before
SonicJS can validate the collection fields.

Conceptual request shape:

```json
{
  "title": "A field note",
  "slug": "a-field-note",
  "status": "published",
  "data": {
    "author": "Example Author",
    "content": { "root": {} }
  }
}
```

The exact content document must satisfy the collection’s current schema; use a
post created by the admin editor as a reference rather than assuming the small
illustrative JSON above is a complete Lexical document.

## Verification

1. Create a draft and confirm that it does not appear in the public endpoint.
2. Publish it in the CMS.
3. Request the public endpoint again and verify the new title and slug.
4. Build or deploy the Astro app and open both `/` and `/posts/<slug>/`.

## Sources

- [SonicJS collections](https://sonicjs.com/collections)
- [SonicJS API reference](https://sonicjs.com/api)
- [SonicJS custom collections deep dive](https://sonicjs.com/blog/creating-custom-collections-in-sonicjs)
- [Astro dynamic routes](https://docs.astro.build/en/core-concepts/routing/)

