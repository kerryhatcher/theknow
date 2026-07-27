---
description: Advisory, CVE, and known-malware data sources for Python packages, endpoints, formats, rate limits, and which three to actually wire in.
---

# Feeds

Every feed here answers one of two questions, and mixing them up causes trouble:

* **Known-vulnerable**: a legitimate package with a published CVE or advisory. OSV, GHSA,
  PyPA, NVD, Safety, Snyk, OSS Index.
* **Known-malicious**: a package uploaded with intent. OpenSSF `malicious-packages`, PyPI
  yanks and quarantine.

Neither catches a novel upload. For that, see [Red flags](red-flags.md). Back to the
[overview](README.md).

## Wire these three and stop

1. **OSV.dev batch API**: the vulnerability backbone. Free, comprehensive, no key.
2. **OpenSSF `malicious-packages`**: the known-malware feed, in OSV format, so the same
   client covers both.
3. **PyPI JSON API**: real-time yank status and metadata signals.

Everything below that line is a special case: GHSA if you need GitHub-derived advisories or
higher rate limits, PyPA if you want Python-specific curation (usually already inside OSV),
and the commercial feeds only if their licensing works for you.

## OSV.dev

Google-run aggregator normalizing GHSA, PyPA, RustSec, and the Global Security Database into
one OSV schema, across PyPI, npm, Cargo, Go, Maven, NuGet, Pub, and more.

**Endpoints**

* Batch: `POST https://api.osv.dev/v1/querybatch`
* Single: `POST https://api.osv.dev/v1/query`

```json
{
  "queries": [
    { "package": { "name": "django", "ecosystem": "PyPI" }, "version": "3.2.0" }
  ]
}
```

Response mirrors input order, each entry carrying a `vulns` array:

```json
{ "results": [ { "vulns": [ { "id": "GHSA-xxxx-xxxx-xxxx", "modified": "2026-01-15T..." } ] } ] }
```

**Limits and gotchas.** Up to 1,000 queries per batch request. Do **not** mix a `version`
field with a versioned PURL in the same query, that returns 400. Pagination via
`next_page_token` when a single query exceeds 1,000 vulns or the batch exceeds 3,000 total.
No documented rate limit; batch efficiently and be polite.

**Freshness.** Hourly to daily, inherited from upstream. A full PyPI dump is at
`gs://osv-vulnerabilities/PyPI/all.zip`, refreshed daily, if you'd rather hold it locally.

**Cost.** Free, open source, no key.

**Note.** OSV-Scanner v2.3.5 (March 2026) added transitive dependency resolution for Python
`requirements.txt` via the deps.dev resolver, closing a gap where Python transitive deps
weren't resolved the way npm and Maven lockfiles already were.

## OpenSSF malicious-packages

The first cross-ecosystem open-source malicious-package database. Covers reported malware,
typosquatting, dependency confusion, protestware, and offensive tooling across npm, PyPI,
RubyGems, and crates.io.

**Access**

* Via OSV API, malicious packages surface in normal OSV query results.
* Directly: clone [`ossf/malicious-packages`](https://github.com/ossf/malicious-packages) and
  read the `osv/` tree, one file per report, organized by ecosystem and package. False
  positives move to `osv/withdrawn/`.
* Live counts: [`ossf.github.io/malicious-packages/stats/`](https://ossf.github.io/malicious-packages/stats/)

```bash
curl -X POST https://api.osv.dev/v1/query -d '{
  "package": {"name": "litellm", "ecosystem": "PyPI"},
  "version": "1.82.7"
}'
```

**Size.** 16,272+ reports as of 2025, growing continuously; secondary sources cite figures up
to ~35,000 across later windows, so read the stats page rather than trusting a number.

**Freshness.** Daily. Contributions arrive by PR and by bulk import from automated detection
pipelines, including OpenSSF's own Package Analysis sandbox.

**Cost/license.** Free, Apache-2.0.

**Interpretation.** Presence means known-malicious. Absence means nothing, discovery lags
publication by days to weeks.

## PyPI JSON API

**Endpoint:** `https://pypi.org/pypi/<package>/json` (add `/<version>/json` for one release).
Free, unauthenticated, real-time.

```bash
curl https://pypi.org/pypi/django/json | jq '.releases."3.2.0"'
```

**Fields that matter for risk**

| Field | Signal |
|---|---|
| `yanked`, `yanked_reason` | Maintainer withdrew the release. Often the first public sign of a compromise. Installers skip yanked versions unless asked explicitly. |
| `upload_time`, `upload_time_iso_8601` | Release timing. Rapid re-releases suggest a panic fix or an active compromise. |
| `last_serial` | Monotonic update counter. A gap can indicate removed versions (quarantine or deletion). |
| `ownership.roles` | Current owners and maintainers (project-level, *not* per-release). A single owner is higher risk than a distributed team; a newly added maintainer warrants scrutiny. Note the path: there is no top-level or `info.roles` key. |
| `requires_dist` | Dependency list. Unexpected network or system-level dependencies are a flag. |
| `requires_python` | Unusually narrow ranges can be a way to exclude analysis environments. |
| `digests` | MD5, SHA-256, BLAKE2b-256 per file. Verify downloads to catch tampering. |
| `vulnerabilities` | Known advisories, with a `withdrawn` flag. Consult OSV for detail. |
| `info.author`, `author_email` | Missing values are a weak compromise signal. |

{% hint style="warning" %}
**Attestations are not on this endpoint.** There is no `provenance` field on
`/pypi/<package>/json`, at the top level or per file. Fetch the Simple API JSON instead
(`curl -H 'Accept: application/vnd.pypi.simple.v1+json' https://pypi.org/simple/<package>/`),
read the per-file `provenance` URL, then GET that URL, which looks like
`https://pypi.org/integrity/<name>/<version>/<filename>/provenance`. See
[Platform defenses](platform-defenses.md).
{% endhint %}

**Ownership is current-state only.** `ownership.roles` reports who owns the project *now*, with no
release or timestamp binding, and the per-release endpoint returns the same object. You cannot
diff maintainers "against the previous release" retrospectively. To detect maintainer churn you
have to poll and store your own snapshots.

**2026 incidents visible through yanks alone:** `xinference` v2.6.0–2.6.2 (base64 payload
stealing secrets on import, yanked April 2026); Microsoft `durabletask` v1.4.1–1.4.3
(credential harvester, May 2026); `pytorch-lightning` v2.6.2–2.6.3 (malware on install, April
2026); `litellm` and `telnyx` (credential exfiltration, March 2026).

**Limits.** Rate limiting is IP-based and unpublished, cache locally. No signature or
provenance data beyond PEP 740. Yanks only appear once a maintainer acts, and quarantine has
no dedicated endpoint at all.

## GitHub Advisory Database (GHSA)

GitHub-curated advisories plus ingested NVD CVEs, including malware advisories. Ecosystem
`PIP` for Python.

```graphql
query {
  securityVulnerabilities(first: 100, ecosystem: PIP, severities: [CRITICAL]) {
    nodes {
      advisory {
        ghsaId
        severity
        cvssSeverities { cvssV3 { score vectorString } cvssV4 { score vectorString } }
        cwes(first: 10) { nodes { cweId name } }
        references { url }
      }
      package { name }
      vulnerableVersionRange
      firstPatchedVersion { identifier }
    }
    pageInfo { hasNextPage endCursor }
  }
}
```

**Access.** GraphQL at `https://api.github.com/graphql` (preferred), or the raw OSV-format
files in [`github/advisory-database`](https://github.com/github/advisory-database).

Three schema details bite here, because the obvious spelling of each is wrong: the filter
argument is `severities` (a list), not `severity`; `severity` is a field on `SecurityAdvisory`
itself while scores live under `cvssSeverities` (the older scalar `cvss` field is gone); and CWEs
come from a `cwes` connection, not a `cweIds` list. Introspect before you widen the selection
(`gh api graphql -f query='{ __type(name: "SecurityAdvisory") { fields { name } } }'`).

**Limits.** 60 requests/hour unauthenticated, 5,000/hour with a token.

**Freshness.** Near real-time; published as discovered or when an embargo lifts.

## PyPA Advisory Database

Community-owned Python advisories, OSV-schema YAML named `PYSEC-YYYY-NNNN.yaml` under
`vulns/`. Sourced from the NVD CVE feed with heuristics matching CVEs to PyPI packages, plus
human curation.

There is no PyPA API. The database *is* the git repo, so consume it as files:

```bash
git clone --depth 1 https://github.com/pypa/advisory-database
ls advisory-database/vulns/jinja2/     # one PYSEC-YYYY-NNNN.yaml per advisory
```

`pip-audit` uses this as a primary source. Repo:
[`pypa/advisory-database`](https://github.com/pypa/advisory-database). Free. The same records reach
you through OSV.dev, aggregated with everything else, so clone it directly only when you want PYSEC
curation and provenance specifically.

## NVD / CVE

NIST's authoritative CVE registry. Python packages are matched by CPE string, which is the
problem: pure-Python packages frequently have imprecise or missing CPE entries.

```bash
curl 'https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=django&startIndex=0&resultsPerPage=20'
```

**Limits.** 5 requests per 30 seconds without a key; 50 with a
[free key](https://nvd.nist.gov/developers/start-here).

**Freshness.** CVE list processed hourly, so new CVEs appear within about an hour of
publication to MITRE. Enrichment (CVSS scoring) lags.

**Verdict for Python:** OSV and GHSA are higher-signal. Use NVD when you specifically need the
source of record. [`nvdlib`](https://nvdlib.com/) wraps the API with built-in rate limiting.

## Safety DB

Python-specific advisory database from pyup.io. The free database is **CC BY-NC-SA 4.0 —
non-commercial only, attribution required**, and it updates monthly, which is too slow to rely
on. The commercial PyUp API updates weekly and needs a key.

```bash
safety check --json > vulns.json
safety check --key "$PYUP_API_KEY"
```

Repos: [`pyupio/safety`](https://github.com/pyupio/safety),
[`pyupio/safety-db`](https://github.com/pyupio/safety-db). Watch the license before shipping
anything built on the free data.

## Snyk

Proprietary curated database, separate from NVD, with a reputation for disclosing within
hours rather than days. Covers pip, poetry, `requirements.txt`, `Pipfile`, `Pipfile.lock`.

**Pricing (2026):** free tier limited to 200 SCA tests and 100 SAST tests per month; Team at
$25/month per contributing developer; Ignite at $1,260/year per developer; Enterprise custom.
"Contributing developer" means anyone who committed to a private repo in the last 90 days.

Cannot be self-hosted or downloaded wholesale, API or CLI only.

## Sonatype OSS Index

Free multi-ecosystem vulnerability data, currently migrating from OSS Index to Sonatype Guide
(milestones 31 March and 28 April 2026), so verify the current endpoint before wiring it in.

```bash
curl -X POST https://api.sonatypecdn.com/api/v3/search \
  -H "Content-Type: application/json" \
  -d '{"packages": ["pkg:pypi/django@3.2"]}'
```

Registration required for a token. Python client:
[`ossindex-python`](https://github.com/sonatype-nexus-community/ossindex-python). Most entries
map directly to NVD CVEs.

## Prioritization: CVSS, EPSS, CWE

* **CVSS**: 0–10 severity from exploitability and impact. **v4.0** has been current since
  November 2023, but v3.1 is what most historical records carry, and GHSA now serves both (see the
  `cvssV3`/`cvssV4` selection above). Parse both and prefer v4 where present, or you drop the
  severity on advisories scored only under v4.
* **EPSS**: a daily ML forecast (0–1) of exploitation in the wild within 30 days, published
  at [first.org/epss](https://www.first.org/epss). A better predictor of real risk than CVSS
  alone.
* **CWE**: the weakness taxonomy (CWE-89 SQL injection, CWE-79 XSS), linked from CVEs and
  OSV records.

Don't wire these as separate feeds. Pull them from the advisories you're already fetching and
combine downstream: high EPSS **and** high CVSS **and** a CWE Top 25 category is your
immediate-action bucket.

## Summary table

| Feed | Access | Cost | Freshness | Best for |
|---|---|---|---|---|
| **OSV.dev** | `POST /v1/querybatch` | Free | Hourly+ | The backbone; batch; transitive deps |
| **OpenSSF malicious** | OSV API or repo clone | Free | Daily | Known malware, typosquats, confusion |
| **PyPI JSON** | `pypi.org/pypi/<pkg>/json` | Free | Real-time | Yanks, metadata, digests, provenance |
| **GHSA** | GraphQL | Free | Near real-time | PyPI CVEs plus malware advisories |
| **PyPA advisory** | Via OSV or repo | Free | Weekly+ | Python-specific curation |
| **NVD** | REST v2 | Free (key raises limits) | ~1 hour | CVE source of record; weak CPE for Python |
| **Safety DB** | CLI or repo | Free (non-commercial) / paid | Monthly / weekly | Python-specific history |
| **Snyk** | REST + CLI | $25+/dev/mo | Hours | Fast proprietary disclosure |
| **Sonatype OSS Index** | REST (migrating) | Free, registration | Maintained | Multi-ecosystem |

## Resolve the tree first

Both CVE lookups and name-risk checks belong against the **resolved** set, not the declared
requirements. `poetry.lock` and `uv.lock` pin the full transitive graph with content hashes by
default, which beats an unpinned `requirements.txt` for reproducibility and tamper detection —
but a lockfile reproduces a bad resolution exactly as faithfully as a good one. Lockfiles
narrow the attack window; they don't close it, and re-resolution after a lockfile goes stale
is itself a moment of exposure.

* [deps.dev](https://deps.dev) (Google Open Source Insights) computes full transitive graphs
  for every indexed version across PyPI, npm, Maven, Go, Cargo, and NuGet, with an API
  (v3alpha, batch and PURL support) and a public BigQuery dataset.
* Locally, `uv pip compile` or `pip freeze` in an isolated environment gets you the same set.

Then batch-query OSV over that whole set, and flag anything both unpinned-by-hash and newly
published.

## Open questions

* No published freshness SLA for OSV batches, practical guidance only.
* Sonatype Guide migration endpoints may still shift post-April 2026.
* PyPI JSON API rate-limit behavior is genuinely undocumented; measure it yourself and cache.
* VulnDB (Tenable) was skipped, proprietary, commercial-only, unsuitable for open tooling.

## Sources

* [OSV.dev](https://osv.dev/) · [batch query API](https://google.github.io/osv.dev/post-v1-querybatch/) · [data sources](https://google.github.io/osv.dev/data/)
* [OpenSSF malicious-packages](https://github.com/ossf/malicious-packages) · [detecting malicious packages using the OSV API](https://openssf.org/blog/2026/05/20/detecting-malicious-packages-using-the-osv-api/)
* [PyPI JSON API docs](https://docs.pypi.org/api/json/) · [yanking on PyPI](https://docs.pypi.org/project-management/yanking/)
* [GitHub Advisory Database](https://github.com/advisories)
* [PyPA advisory database](https://github.com/pypa/advisory-database)
* [NVD developers: start here](https://nvd.nist.gov/developers/start-here) · [API key announcement (rate limits)](https://nvd.nist.gov/general/news/API-Key-Announcement)
* [Safety](https://pypi.org/project/safety/) · [safety-db](https://github.com/pyupio/safety-db)
* [Snyk pricing](https://snyk.io/plans/)
* [Sonatype Guide API](https://guide.sonatype.com/api) · [OSS Index migration guide](https://help.sonatype.com/en/oss-index-migration-to-sonatype-guide.html)
* [EPSS](https://www.first.org/epss) · [CWE](https://cwe.mitre.org/)
* [pip-audit](https://github.com/pypa/pip-audit) · [OSV-Scanner](https://github.com/google/osv-scanner) · [nvdlib](https://nvdlib.com/)
