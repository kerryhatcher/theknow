---
description: Typosquatting, combosquatting, dependency confusion, starjacking, account takeover, and repo-vs-artifact divergence on PyPI.
---

# Name and distribution attacks

The attacks that don't need a single line of clever code: get the victim to install the wrong
package, or get your code into the right package's artifact. Back to the
[overview](README.md); code-level indicators are on [Red flags](red-flags.md).

## Typosquatting

Publishing a package whose name is close enough to a popular one that a typo, a homoglyph, or
a glance installs yours instead.

### Attack vectors

**Character-level**

* Single-character error: `reuqests` for `requests` (transposition), `rquests` (omission)
* Insertion: `numppy` for `numpy`
* Visual homoglyph: lowercase `l` → capital `I`, Latin `a` → Cyrillic `а` (edit distance 1, visually identical in most fonts)
* Keyboard proximity: `o` for `p`, adjacent keys

**Name-shape-level**

* Separator swap: `scikitlearn` vs `scikit-learn`, `colorama-tool` vs `colorama_tool`
* Pluralization: `requests-list` vs `requestlist`
* Prefix/suffix: `colorama-lib`, `my-colorama`, `python-request`
* British/American spelling: `colourama` for `colorama`

### Verified incidents

| Date | Package | Detail |
|---|---|---|
| 2017, again 2022 | `colourama` | British spelling of `colorama`; stole SSH and GPG keys |
| Dec 2019 | `jeIlyfish` | Capital `I` for lowercase `l` in `jellyfish`; hit `python3-dateutil` in the same campaign; 119 downloads before removal; exfiltrated SSH/GPG keys to a C2 |
| 2022 | `ctx` | Domain resurrection → account takeover; malicious versions never existed in the GitHub repo |
| 2022 | `colorama` family | Coordinated misspelling + combosquat campaign (`colourama`, `colorama-lib`), registering many similar names to widen the net |
| Mar 2024 | ~365–500+ packages in 24h (counts differ by source) | Mass typosquat registration campaign; PyPI suspended new project creation *and* new user registration for about 10 hours (02:16–12:56 UTC, 2024-03-28) and tightened automated defenses |
| Mar 2026 | ~500 packages | Phylum and Check Point independently flagged an impersonation campaign against `requests`, `colorama`, `capmonster-cloud`, and dozens more, with AI-generated name variations |

### Detection algorithms and their limits

**Levenshtein distance.** Minimum single-character edits between two strings. Distance 1 is
high-confidence suspicious; distance 2 is moderate. Compare against a reference set of the
top ~5,000 PyPI packages by download count (about 10 KB of data), and only evaluate *new*
packages, never popular ones.

Limits: homoglyphs score distance 1 while being visually identical, and a keyboard-adjacent
slip scores the same as a random substitution.

**Damerau-Levenshtein.** Adds adjacent transposition as a single edit, which matches how
people actually mistype. Against `requests`, the swap typo `reuqests` scores **1** under
Damerau-Levenshtein where plain Levenshtein charges it **2** (two substitutions). That shifts
where a threshold bites: transpositions that plain edit distance rates as distance 2, and so
leaves in the "moderate" bucket, become distance-1 hits.

**Keyboard proximity scoring.** Penalize QWERTY-adjacent substitutions less than distant
ones. Cuts false positives, costs more compute.

**Popularity thresholds.** SpellBound/TypoGard applies name transformations to known
packages and compares candidates against the popular set; with a 15,000-weekly-download
threshold the reported alert rate is ~0.05% for npm and ~0.5% for PyPI. Lower FP than naive
edit distance alone. (Those two percentages are carried from secondary summaries. They have not
been verified against a SpellBound or TypoGard paper, and no such paper is in the source list
below. Treat them as unverified.)

**Recipe 1: typosquat screen (single-digit ms per package)**

```python
def check_typosquat(package_name, top_packages, top_set):
    # Transpositions: generate once, test by set membership. O(len(name)), not O(len(name) × N).
    swaps = {package_name[:i] + package_name[i+1] + package_name[i] + package_name[i+2:]
             for i in range(len(package_name) - 1)}
    hit = swaps & top_set
    if hit:
        return ("TYPOSQUAT_TRANSPOSITION", hit.pop())

    n = len(package_name)
    for popular in top_packages:
        if abs(len(popular) - n) > 1:      # cheap prefilter before the DP
            continue
        if levenshtein_distance(package_name, popular) <= 1:
            return ("TYPOSQUAT", popular)
    return None
```

Generate the transposition set **outside** the loop over popular names. Comparing every
transposition against every popular name, as the obvious nesting does, is needlessly quadratic.

**Cost, measured against 5,000 reference names** (worst case, no match, so the full set is
scanned): roughly **10ms** per package in pure Python with the length prefilter above, and around
60–100ms without it, since a naive full-matrix edit distance runs 5,000 times. A C-accelerated
library (`rapidfuzz`, `python-Levenshtein`) brings it into the low single-digit milliseconds. So
this is cheap enough for a batch sweep or a CI gate, but at ~10ms it is *not* free at install time:
a 200-package resolved tree costs a couple of seconds. Bucket candidates by length or first
character before the distance loop if you need install-time latency.

Distance ≤1 makes a candidate immediately; distance 2 with both characters keyboard-adjacent is
medium confidence. Neither blocks on its own: real sibling packages sit one edit apart.

### Beyond edit distance: ConfuGuard

[arXiv:2502.20528](https://arxiv.org/abs/2502.20528) (Jiang, Çakar, Lysenko, Davis) is the
current state of the art, accepted at **USENIX Security 2025**. It appeared as *TypoSmart* in
v1 and became *ConfuGuard* in later versions, same paper, same arXiv ID; cite it as
ConfuGuard.

What it adds:

* **Fine-tuned embeddings instead of string distance.** Starts from FastText's
  `cc.en.300.bin` and fine-tunes on a large corpus of package names drawn from the registries it
  covers, so the embedding space captures domain-specific similarity. This is why it catches
  `python-request`, a token addition, not a typo, which Levenshtein at distance 1–2 misses
  entirely. (Secondary write-ups quote a corpus of 9.1 billion names, which is not credible
  against a cross-registry namespace on the order of 10^7 packages. Check the paper before
  repeating any corpus size.)
* **Metadata-driven FP suppression.** ConfuGuard layers benign signals (multi-release history,
  consistent maintainer identity, real repo linkage) and cuts reported FPs from roughly 80% to
  28%, a **65% relative reduction** compared with prior work.
* **Scale.** Coverage extended from 3 to 7 registries, with a reported 73–91% speedup, which
  is what makes an install-time or continuous-sweep deployment plausible.

{% hint style="info" %}
Its production-deployment numbers appear inconsistently across secondary sources, 630
attacks in one framing, 301 confirmed threats over three months and 3,658 typosquat packages
removed in a month in others. These look like different measurement windows of the same
deployment rather than contradictions, but treat the exact figure as unresolved.
{% endhint %}

**The takeaway for any detector:** edit distance is a first-pass filter, not a classifier. The
FP problem was never "did we find something similar", it's "is this similar-but-legitimate or
an attack", and answering that needs metadata and history layered on top of name similarity.

## Combosquatting

Appending or prepending words to a legitimate name. Not a typo, it exploits the assumption
that `colorama-tool` is an official companion to `colorama`.

Edit distance is blind here: `colorama-tool` is 5+ edits from `colorama` but reads as
near-identical to a person. So use a token-based check instead: split on `-`/`_`, strip
tokens from a small suspicious vocabulary (`dev`, `test`, `tool`, `cli`, `lib`, `utils`,
`helper`, `wrapper`, `sdk`, `api`, `official`, `pro`, `python-`, `-extra`), and flag when the
remaining core exactly matches a top-N package.

Documented examples: `noblox.js-async` and `noblox.js-proxy-server` (2020, targeting Roblox
developers by mimicking the ecosystem's naming style); `colorama-lib`, `colorama-tool`,
`colorama-extra`.

### Homoglyph skeletons

A distinct algorithm, not an edit-distance variant. The Unicode Consortium publishes
`confusables.txt`, the same data browsers use for IDN homograph defense, mapping look-alike
codepoints (Cyrillic а/е/о/р, Greek characters, full-width Latin) to a canonical ASCII
"skeleton". Two names collide if their skeletons match, even when raw edit distance is 0
(identical glyphs, different codepoints) or high (different codepoints rendering
identically).

This is the correct tool for the `jeIlyfish` class of attack. Pixel-rendering comparison also
works but skeleton lookup is orders of magnitude cheaper.

**Phonetic similarity (Soundex, Metaphone) is overkill.** Package names get typed, not
spoken. Phonetic collision matters for domain squatting, where a victim mishears a name; it
does not matter for `pip install`.

## Starjacking

PyPI displays repository statistics from whatever GitHub URL a package declares, and does not
verify that the package has anything to do with that repository.

1. Attacker publishes a malicious package with a plausible description.
2. Metadata points `home_page` at an unrelated popular project with 50,000 stars.
3. The PyPI page shows that star count.
4. A developer reads inflated stats as evidence of trustworthiness.

**Detection signal:** a linked repo with high stars alongside near-zero download counts for
the package itself.

## Dependency confusion

Disclosed by **Alex Birsan, 9–10 February 2021**. Exploits resolution order: publish a
package to public PyPI using an organization's *internal* package name with a higher version,
and a build that consults PyPI (or prefers the higher version) installs yours.

**Mechanics**

1. Harvest internal package names from public GitHub commits, job postings, company sites, or
   accidentally published internal packages.
2. Publish that name to PyPI at version `99.0.0`.
3. The victim's CI or developer machine resolves against PyPI and picks the higher version.
4. Install-time code runs, taking credentials, SSH keys, environment variables, cloud tokens.

**Scope of the original disclosure:** Apple, Microsoft, PayPal, Yelp, Uber and others; 35+
organizations confirmed vulnerable across Python, npm, and Ruby; over $130,000 in bug
bounties.

**Recipe 2: confusion surveillance (~1ms per internal name)**

```python
def check_confusion(org_packages, pypi_registry, org_email_domains, our_reserved_names):
    findings = []
    for internal_name in org_packages:
        pkg = pypi_registry.get(internal_name)
        if not pkg or internal_name in our_reserved_names:
            continue                       # names we published ourselves are not findings
        # Naive squatter versions only; a careful attacker just uses latest + 1.
        if pkg["latest_version"].startswith(("99.", "100.")):
            findings.append(("DEPENDENCY_CONFUSION_VERSION", internal_name,
                             pkg["latest_version"]))
            continue
        email = (pkg.get("maintainer_email") or pkg.get("author_email") or "")
        domain = email.rpartition("@")[2].lower()
        # Compare DOMAIN against domains. Comparing the full address never matches.
        if not domain or domain not in org_email_domains:
            findings.append(("DEPENDENCY_CONFUSION_OWNER", internal_name,
                             email or "no-email"))
    return findings
```

Two traps in that comparison. Test the **domain** against `org_email_domains`, not the whole
address: `"release-bot@example.com" not in {"example.com"}` is always true, so the naive version
alerts on every internal name that exists on PyPI at all. And keep an allowlist of names you
reserved yourself, because prevention step 1 below tells you to pre-register your whole internal
namespace: without the allowlist, following both pieces of advice means alerting on your own
reservations forever. A missing maintainer email is a finding rather than a pass, since PyPI
projects frequently populate only `author_email`. Accumulate findings instead of returning on the
first hit, or one squatted name hides the rest.

Data sources: your own internal package inventory (keep it in version control), the PyPI JSON
API, or the `bigquery-public-data.pypi` public dataset for snapshot-based scanning.

**Prevention, in order of effectiveness**

1. **Namespace reservation**: pre-register every internal name on public PyPI, even unused,
   so nobody else can.
2. **Single-index configuration**: point `index-url` at exactly one index, either a private index
   or a pull-through proxy that fronts PyPI. pip has **no index priority**: `--extra-index-url`
   merges candidate sets and the resolver picks by version, so a `99.0.0` on public PyPI wins no
   matter which index you list first. Ordering entries in `pip.conf` buys you nothing, and
   `.pypirc` is upload configuration that pip never reads during installation. If you genuinely
   need two indexes, use a resolver with explicit priority (`uv --index-strategy first-index`) or a
   proxy that shadows internal names.
3. **Version pinning**: pin exact versions rather than allowing auto-upgrade.
4. **CI isolation**: no implicit public index in build environments.
5. **2FA and strong credentials** on the private index.
6. **Periodic inventory scans**: check whether any internal name has appeared publicly.

[PEP 708](https://peps.python.org/pep-0708/) extends the repository API specifically to
mitigate this at the protocol level, by letting an index declare which projects it is
authoritative for.

## Account takeover and release hijacking

The nastiest class, because the source repository stays clean and every code-level heuristic
on the repo passes.

**Vectors**

* **Credential compromise**: weak or reused passwords, phishing, brute force against
  accounts without 2FA.
* **Domain resurrection**: the maintainer's email domain expires, the attacker re-registers
  it, then triggers a PyPI password reset to that address. No password cracking required.
  PyPI blocked multiple such attempts across 2023–2024.
* **Third-party compromise**: GitHub account, CI system, or wherever the API token lives.

**Verified incidents**

* **`ctx` (2022).** Maintainer's domain expired and was re-registered; malicious versions
  published that were never in the legitimate repo.
* **LiteLLM (March 2026).** Maintainer account compromised; v1.82.7 and v1.82.8 uploaded
  directly via `twine`, never through the project's GitHub CI. Payload stole cloud
  credentials, crypto keys, and Slack/Discord tokens. Threat actor attributed to TeamPCP by
  Trend Micro. Exposure window 2h32m from upload to quarantine (1h19m to the first report, then
  1h12m to quarantine), and roughly 119,000 downloads happened inside it.
* **Microsoft `durabletask` (May 2026).** v1.4.1–1.4.3 malicious. Same shape: once the
  account was controlled, shipping weaponized wheels was one `twine upload`. Payload was a
  Linux wiper plus a cloud credential stealer.

**Detection.** Watch for metadata changes across releases (maintainer email, repo link,
description); a long-dormant package suddenly shipping a version whose contents don't
correspond to any repo change; a maintainer email domain that has changed hands; new API
tokens or tokens used from unexpected geographies.

**Prevention**, strongest first.
[Trusted Publishing](platform-defenses.md#trusted-publishing-and-attestations) comes first,
because it is the only item here that makes a stolen credential insufficient to publish. Then
short-lived API tokens rather than passwords for CI, and token rotation. 2FA (mandatory on PyPI
since 2024-01-01) protects the browser-side account but **does not gate uploads**, which is why
both incidents above happened after the mandate: the attacker published with a token, and no
second factor was ever requested.

{% hint style="info" %}
This is the maintainer-concentration risk from
[Small World with High Risks](https://arxiv.org/abs/1902.09217) (USENIX Security 2019) in
practice. On npm, installing an average package implicitly trusts ~79 packages and ~39
maintainers. No PyPI-specific replication of that measurement exists, but LiteLLM and
`durabletask` are the mechanism in action.
{% endhint %}

## Repo-vs-artifact divergence

The LastPyMile approach (Vu, Massacci, Pashchenko, Plate, Sabetta; ESEC/FSE 2021), and the
technique with the best signal-to-noise ratio in this whole topic.

**The attack it catches:** the attacker never touches the source repository. They inject only
into the built wheel, via account takeover or a compromised build pipeline. Anyone reading
the GitHub repo sees clean code; anyone running `pip install` gets the payload.

**Method, two stages**

1. **Find the discrepancies.** Download the artifact (wheel or sdist), clone the repo, hash
   and compare. *Phantom files* exist in the artifact but not the repo. *Modified files*
   share a path but differ in content. Then diff to the line level.
2. **Scan only the discrepancies.** YARA rules for known malware signatures, plus AST
   analysis (Bandit4mal-style rules) for subprocess calls, filesystem operations, network
   connections, environment access, and decode-then-exec.

**Why it wins:** it reduces the analysis surface to injected code only, so the legitimate
patterns in the developer's own code never generate alerts. Be careful how you quote its numbers.
The paper reports no precision or recall figure, and a widely repeated "<1% FP at ~95% detection"
pair appears nowhere in it. What it does report is a validation on three malicious and three benign
artifacts, where the malicious ones were all detected, alert counts on them dropped by one to two
orders of magnitude (1,044 Bandit alerts down to 12 on `urlib3-1.21.1`, 489 down to 12 for
Warehouse Malware Checks on `setup-tools-36.0.1`), and the benign artifacts produced no alerts at
all. That is a strong alert-reduction result on a small manual sample, not a benchmarked FP rate
comparable to the other rows on
[Detection quality](detection-quality.md#benchmark-numbers).

**Recipe 4 sketch (5–30s per package)**

```python
def check_artifact_divergence(repo_url, artifact_path, version_tag, workdir):
    art_root, src_root = workdir / "artifact", workdir / "source"
    extract(artifact_path, art_root)

    # Full clone, then check out the tag matching the release under analysis.
    # A --depth=1 clone gets the tip of the default branch, so ordinary post-release
    # commits show up as "modified files" and manufacture divergence on healthy packages.
    # This tag checkout is the cheap approximation; the full-history variant below is
    # what actually keeps the alert volume down.
    subprocess.run(["git", "clone", repo_url, src_root], check=True)
    subprocess.run(["git", "-C", src_root, "checkout", version_tag], check=True)

    # Key both sides on paths RELATIVE to their own root, or nothing ever compares equal
    # and the entire artifact reads as phantom.
    artifact_files = {p.relative_to(art_root): p for p in find_python_files(art_root)}
    source_files = {p.relative_to(src_root): p for p in find_python_files(src_root)}

    findings = []                  # accumulate: one injected file must not hide the rest
    for rel in artifact_files.keys() - source_files.keys():
        # scan_with_yara takes bytes at both call sites, here and on the diff below.
        if (scan_with_yara(artifact_files[rel].read_bytes(), MALWARE_RULES)
                or run_bandit(artifact_files[rel])):
            findings.append(("PHANTOM_FILE_MALICIOUS", rel))

    for rel in artifact_files.keys() & source_files.keys():
        if hash_file(artifact_files[rel]) != hash_file(source_files[rel]):
            diff = compute_diff(source_files[rel], artifact_files[rel])
            if scan_with_yara(diff.encode(), MALWARE_RULES):
                findings.append(("MODIFIED_FILE_MALICIOUS", rel, diff))
    return findings
```

The two details that decide whether this works at all: compare on **relative** paths, and compare
against the **release**, not `HEAD`. Where no tag maps to the version, hash every blob reachable
from any commit (`git rev-list --objects --all`) and call a file phantom only if its hash appears
nowhere in history. That full-history comparison is what LastPyMile actually does, and it is where
the low alert volume comes from. The tag-checkout sketch above is the cheap approximation: a
`HEAD`-only shallow clone is worse again, because ordinary post-release commits then read as
divergence on healthy packages.

Thresholds: a phantom file with a YARA match blocks immediately; Bandit findings in a phantom
or modified file get reviewed; a modified file whose diff is >50% additions is medium
confidence. Costs: 1–10 MB artifact download, a full clone plus tag checkout (5–30s, more on large
repos), 1–5s of scanning per file. Suitable for post-download verification or periodic deep scans
of critical packages, not for a real-time install gate.

**Prerequisite and its limitation:** you need to know the real source repository.
[py2src](https://github.com/simonepirocca/py2src) (Duc-Ly Vu, ASE 2021) automates that
inference and scores its own reliability from -4 to +4. Where no repo exists or the link is
wrong, this technique simply doesn't apply, which is also why starjacking matters.

**Instances it would have caught:** `ctx` (2022), `aiocpa` (2024), LiteLLM (2026),
`durabletask` (2026). All four were artifact-only compromises, with the payload in the published
package and never in the repo.

## Metadata red flags recipe

**Recipe 3 (~500ms per package; needs WHOIS, the GitHub API, and a download-stats source)**

```python
def check_metadata_flags(pkg, downloads_last_week=None):
    flags = []
    if not pkg.get("summary") or len(pkg["summary"]) < 10:
        flags.append("MISSING_DESCRIPTION")
    if pkg["version"] == "0.0.0":
        flags.append("VERSION_000")
    # Same fallback as Recipe 2: PyPI projects often populate only author_email,
    # and an absent address must not reach extract_domain().
    email = pkg.get("maintainer_email") or pkg.get("author_email") or ""
    domain = extract_domain(email)
    if domain and is_recently_registered(domain, days=30):
        flags.append("DOMAIN_RESURRECTION")
    if pkg.get("home_page", "").startswith("https://github.com/"):
        # Guard the sentinel: PyPI's JSON API reports -1 for every download counter.
        # Star fetch second, so the cheap test short-circuits the rate-limited one.
        if (downloads_last_week is not None and 0 <= downloads_last_week < 100
                and fetch_github_stars(pkg["home_page"]) > 5000):
            flags.append("STARJACKING_SIGNAL")
    if pkg["name"] not in pkg.get("description", ""):
        flags.append("NAME_MISMATCH")
    return flags
```

One flag is informational. Two or more warrants review. `DOMAIN_RESURRECTION` or
`STARJACKING_SIGNAL` alone is high confidence, both are near-impossible to hit accidentally.

Where the download count comes from matters more than it looks. PyPI's JSON API returns
`info.downloads` as `{"last_day": -1, "last_week": -1, "last_month": -1}` for every project, a
placeholder rather than data, so real counts have to come from pypistats.org or the
`bigquery-public-data.pypi` dataset. Pass the `-1` straight through and the starjacking branch
degenerates into "links a popular repo", which is true of a great many honest packages.

Cost note: GitHub's unauthenticated API allows 60 requests/hour, so cache aggressively. WHOIS
runs ~500ms per query unless you use a batch API. This is an hourly or daily scan, not a
real-time one.

## Attestation check

**Recipe 5 (~10ms per package)**: validate a PEP 740 / SLSA provenance attestation rather
than inspecting code at all: fetch the provenance, verify the signature against trusted
roots, confirm the builder identity matches the expected CI workflow, and confirm the built
source digest matches the repository. No attestation is medium risk (most packages still lack
one); an invalid signature or a source mismatch is a block. Details and current adoption
numbers are on [Platform defenses](platform-defenses.md).

## Detection recipes ranked

| # | Recipe | Cost | FP rate | Catches |
|---|---|---|---|---|
| 1 | Levenshtein typosquat screen | ~10ms pure Python, ~1–5ms with a C-accelerated distance | High as a classifier: prior string-distance work reports ~80% FP, and ConfuGuard only reaches 28% by adding metadata. Output is a candidate list for stage 2, never a block | Most classic typosquats |
| 2 | Dependency-confusion surveillance | ~1ms/name | Low, *provided* you allowlist your own reserved names | Internal-name collisions, `99.x` versions |
| 3 | Metadata red flags | ~500ms | Medium | Domain resurrection, starjacking, placeholders |
| 4 | Repo-artifact divergence | 5–30s | Low, and the lowest here, *provided* you compare against full history; much worse against a shallow `HEAD` clone. No published rate, see the caveat above | Account takeover, build compromise |
| 5 | Attestation validation | ~10ms | n/a | Unauthorized publishers — where adopted |

Add one more filter on top of all of them: run name-risk checks against the **full resolved
tree**, then flag anything that is both unpinned-by-hash and newly published (first release
under ~30 days old). That intersection is precisely the typosquat and confusion window.
[deps.dev](https://deps.dev) computes full transitive graphs by API or BigQuery;
`uv pip compile` or `pip freeze` in a throwaway environment does it locally.

## Sources

* [ConfuGuard: using metadata to detect active and stealthy package confusion attacks](https://arxiv.org/abs/2502.20528), arXiv:2502.20528, USENIX Security 2025 (formerly TypoSmart)
* [Typosquatting and combosquatting attacks on the Python ecosystem](https://conferences.computer.org/eurosp/pdfs/EuroSPW2020-7k9FlVRX4z43j4uE2SeXU0/859700a508/859700a508.pdf), Vu, Pashchenko, Massacci, Plate, Sabetta; IEEE EuroS&P Workshops 2020
* [LastPyMile: identifying the discrepancy between sources and packages](https://research.vu.nl/ws/portalfiles/portal/226504739/LastPyMile.pdf), Vu et al., ESEC/FSE 2021
* [py2src](https://github.com/simonepirocca/py2src), automatic identification of PyPI source repositories (ASE 2021)
* [Dependency confusion: how I hacked into Apple, Microsoft and dozens of other companies](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610), Alex Birsan, Feb 2021
* [PEP 708: extending the repository API to mitigate dependency confusion](https://peps.python.org/pep-0708/)
* [PEP 541: package index name retention](https://peps.python.org/pep-0541/)
* [Security risks with Python package naming: typosquatting and beyond](https://snyk.io/articles/security-risks-python-package-naming-convention-typosquatting-and/), Snyk
* [Package names repurposed to push malware on PyPI](https://www.reversinglabs.com/blog/package-names-repurposed-to-push-malware-on-pypi), ReversingLabs
* [Malicious PyPI user strikes again with typosquatting, starjacking, and tailor-made malware](https://checkmarx.com/blog/malicious-pypi-user-strikes-again-with-typosquatting-starjacking-and-unpacks-tailor-made-malware-written-in-c/), Checkmarx
* [PyPI incident report: LiteLLM/Telnyx](https://blog.pypi.org/posts/2026-04-02-incident-report-litellm-telnyx-supply-chain-attack/), official PyPI post-mortem
* [Unicode confusables data](https://www.unicode.org/Public/security/latest/confusables.txt), Unicode Consortium
* [ecosyste-ms typosquatting dataset](https://github.com/ecosyste-ms/typosquatting-dataset), known malicious-to-legitimate name mappings
* [Small World with High Risks](https://arxiv.org/abs/1902.09217), arXiv:1902.09217, USENIX Security 2019
