---
description: How to tell whether a PyPI package is vulnerable, known-malicious, or a novel supply-chain attack, and what each of those needs.
---

# Detecting malicious Python packages

A distillation of a two-round research sweep into PyPI supply-chain attacks and how to detect
them: 32 papers (28 arXiv plus 4 conference works), vendor threat research from Datadog,
Sonatype, ReversingLabs, Phylum, Checkmarx, Socket, and Endor Labs, official PyPI/PyPA and
OpenSSF documentation, and the source of every open-source tool named here.

**Findings current as of July 2026.** The feeds and platform defenses move slowly; the evasion
side moves monthly. Re-verify anything load-bearing before you build on it.

## Start here: three problems, three mechanisms

The single most useful framing in this whole topic. "Is this package safe?" is really three
different questions, and conflating them is why so many tools disappoint.

<table><thead><tr><th width="180">Problem</th><th>What it looks like</th><th>What catches it</th></tr></thead><tbody><tr><td><strong>Known-vulnerable</strong></td><td>A real CVE in a real library. Nobody meant any harm.</td><td>Advisory feeds. Batch-query OSV.dev over the full <em>resolved</em> dependency tree. See <a href="feeds.md">Feeds</a>.</td></tr><tr><td><strong>Known-malicious</strong></td><td>Uploaded with intent, already reported and pulled.</td><td>The OpenSSF <code>malicious-packages</code> OSV feed, plus PyPI yanks and quarantine. See <a href="feeds.md">Feeds</a> and <a href="platform-defenses.md">Platform defenses</a>.</td></tr><tr><td><strong>Novel malicious upload</strong></td><td>Live right now, nobody has flagged it.</td><td>No feed helps. Heuristics, then a sandbox, then LLM triage. See <a href="red-flags.md">Red flags</a>. This is the only reason to build anything.</td></tr></tbody></table>

The first two are lookups against somebody else's work and you should just do them. The third
is the actual engineering problem, and everything hard on this wiki is about that.

## The scale of the thing

| Number | Value | Source |
|---|---|---|
| Packages on PyPI | 717,280+ | PyPI, 2025 |
| Releases per month | ~500,000 | Aggregate PyPI upload volume |
| Benign:malicious **package-count** ratio | ~70:1 | Estimated from ~10k known-malicious against ~707k benign. Not the per-release prior a scanner faces, which is nearer 1 in 10,000. See [Detection quality](detection-quality.md#the-false-positive-crisis) |
| Known-malicious packages catalogued (OpenSSF) | 16,272+ (2025), growing | [`ossf/malicious-packages`](https://github.com/ossf/malicious-packages) |
| Known-malicious with source archived (DataDog) | 1,965 PyPI, 3,611 npm | [DataDog dataset](https://github.com/DataDog/malicious-software-packages-dataset) |
| Malicious packages that reach a user project | 74.81% | [ASE 2023 empirical study](https://arxiv.org/abs/2309.11021) |
| Malicious packages still on PyPI mirrors after removal | 72%+ | Same study |
| Malicious packages using obfuscation | 43.4% | Same study |
| Measured false-positive rates of Python malware scanners | **15%–97%** | [arXiv:2209.13288](https://arxiv.org/abs/2209.13288) |
| FP rate PyPI admins say they'd need to act on alerts | <0.01% | Same benchmark study, from maintainer interviews |

Those last two lines are the whole tension. At 500k releases a month, a 1% false-positive
rate is 5,000 false alarms; 0.1% is still 500. Any design that doesn't take precision
seriously is not a design.

## The staged pipeline

Every credible tool and paper converges on the same shape: cheap-to-expensive stages, each
one only running on what the previous stage flagged.

<table><thead><tr><th width="80">Stage</th><th width="150">What</th><th width="110">Latency/pkg</th><th>Notes</th></tr></thead><tbody><tr><td>1</td><td>Metadata heuristics</td><td>0.1–1s</td><td>Age, release count, maintainer history, downloads, repo link, name similarity. Cheapest, weakest.</td></tr><tr><td>2</td><td>Static / AST analysis</td><td>0.5–2s</td><td>Semgrep-style rules: install hooks, decode-then-<code>exec</code>, credential-read-to-network taint. Reuse GuardDog here.</td></tr><tr><td>3</td><td>Dynamic sandbox</td><td>5–30s</td><td>Install and import under gVisor, record syscalls/network/file access. Catches runtime-only behavior.</td></tr><tr><td>4</td><td>LLM triage</td><td>2–10s per decision</td><td>Intent judgement on the survivors, structured output, human in the loop.</td></tr></tbody></table>

Cost per 1,000 packages, single machine: stage 1 is negligible and parallelizes; stage 2 is
roughly 5–30 CPU-minutes; stage 3 is 2–8 hours and is the bottleneck; stage 4 you run on
tens of packages, not thousands. Run 1 and 2 always, 3 on static hits, 4 on stage-3 findings
plus the human review queue.

## Require two independent signals

{% hint style="warning" %}
Never ship a single-signal HIGH alert. `base64` plus `exec` is completely normal in build
hooks, plugin loaders, and templating engines. What distinguishes malware is the
*combination*: obfuscation **and** a credential read **and** a network sink, or an install
hook **and** a download.
{% endhint %}

The scoring scheme, in full, is on [Detection quality](detection-quality.md). The short
version:

* Tier 1, install-time execution: weight 5
* Tier 2, obfuscation: weight 3
* Tier 3, network or credential access: weight 3 (1 inside an SDK that legitimately needs credentials)
* Tier 4, metadata oddities: weight 1
* Tier 5, sandbox evasion: weight 1

0–2 points is informational, 3–5 needs human review, 6+ blocks. Each tier contributes its
weight **at most once**, however many signals fire inside it, so 6+ points is only reachable by
combining **two different tiers**: corroboration falls out of the arithmetic instead of being a
rule you enforce on the side. Tier 1 + Tier 3 (an install hook that exfiltrates credentials) is
the canonical confirmed-malicious pair.

## Four things that actually move the needle

1. **Differential analysis beats pattern matching.** Comparing the source repo against the
   published artifact, the LastPyMile approach, reports <1% FP at ~95% detection, because
   it shrinks what you analyze down to the diff. A clean repo with a dirty wheel is a
   near-certain post-publish compromise, and that's exactly the shape of the two biggest
   2026 incidents. See [Name and distribution attacks](name-attacks.md#repo-vs-artifact-divergence).
2. **Scan the resolved tree, not the declared one.** Expand to every transitive package
   first, then run name checks and CVE lookups over that set. A lockfile reproduces a bad
   resolution exactly as faithfully as a good one.
3. **Name similarity is a filter, not a classifier.** Edit distance answers "is this
   similar", never "is this an attack". ConfuGuard (USENIX Security 2025) cut false positives
   about 65% over prior work (80% down to 28%) by layering maintainer and release-history
   metadata on top of name-embedding similarity.
4. **Static analysis sees calls, not intent.** `exec()` is byte-identical in a plugin system
   and in a stealer. That gap is precisely what the sandbox and [LLM triage](llm-triage.md)
   stages exist to close, and why the LLM is a second-stage triager and never a scanner.

## Incident timeline (verified)

The cases the research keeps returning to, because each one demonstrates a distinct mechanism.

| Date | Package(s) | Mechanism |
|---|---|---|
| Nov 2015 – Nov 2019 | 174 packages across three ecosystems | The Backstabber's Knife corpus: the first systematic look |
| Dec 2019 | `jeIlyfish`, `python3-dateutil` | Homoglyph typosquat (capital I for lowercase l); 119 downloads; SSH/GPG key theft |
| Feb 2021 | 35+ orgs incl. Apple, Microsoft, PayPal | Dependency confusion (Alex Birsan), $130k+ in bounties |
| 2022 | `ctx` | Domain resurrection → account takeover → malicious versions never in the repo |
| 2022 | `colorama` family, W4SP Stealer | Typosquat + combosquat campaign; 45,000+ downloads |
| 2023 | BlazeStealer | Malware disguised as an obfuscation tool |
| Nov 2024 | `aiocpa` | Recursive base64 + zlib payload in `utils/sync.py`, present only in the PyPI artifact and never in the GitHub repo |
| Mar 2026 | `litellm` v1.82.7/1.82.8 | Maintainer account takeover (TeamPCP); `.pth` startup hook; ~119k downloads in a 2h32m window |
| Mar 2026 | ~500 packages | Phylum and Check Point both flagged an AI-generated typosquat campaign |
| May 2026 | Microsoft `durabletask` v1.4.1–1.4.3 | Account takeover; Linux wiper plus cloud-credential stealer |

## What nobody has solved

* **No mature open-source dynamic sandbox aimed at a laptop pre-install gate.** OpenSSF
  `package-analysis` is the closest thing and it wants `--privileged` Docker and a fleet
  pipeline behind it.
* **No public tool systematically audits sdist-vs-wheel mismatch at scale.** The manifest
  confusion gap is documented and mostly checked by hand.
* **No PyPI equivalent of the npm trust-concentration measurement.** Installing an average
  npm package implicitly trusts ~79 packages and ~39 maintainers
  ([USENIX Security 2019](https://arxiv.org/abs/1902.09217)). The mechanism plainly
  transfers, LiteLLM and `durabletask` are that risk playing out, but the PyPI numbers are
  unmeasured.
* **The evasion arms race outruns rule updates.** Every static rule discussed here has a
  documented published bypass. See [Detection quality](detection-quality.md#the-evasion-arms-race).
* **LLM economics are unmeasured for local hardware.** Real tokens/sec and the false-positive
  rate on benign ML packages that legitimately use `base64` + `exec` are both open questions.

## Pages

<table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>Red flags</strong></td><td>The heuristic taxonomy with code, tiered by confidence.</td><td><a href="red-flags.md">red-flags.md</a></td></tr><tr><td><strong>Name and distribution attacks</strong></td><td>Typosquatting, confusion, starjacking, takeover, repo-vs-artifact.</td><td><a href="name-attacks.md">name-attacks.md</a></td></tr><tr><td><strong>Feeds</strong></td><td>Advisory and malware data sources, with queries and limits.</td><td><a href="feeds.md">feeds.md</a></td></tr><tr><td><strong>Scanners</strong></td><td>The OSS and commercial tool landscape, and how to layer it.</td><td><a href="scanners.md">scanners.md</a></td></tr><tr><td><strong>Platform defenses</strong></td><td>What PyPI, PyPA, and OpenSSF ship, and what you can query.</td><td><a href="platform-defenses.md">platform-defenses.md</a></td></tr><tr><td><strong>Detection quality</strong></td><td>False positives, the evasion arms race, confidence scoring.</td><td><a href="detection-quality.md">detection-quality.md</a></td></tr><tr><td><strong>LLM triage</strong></td><td>Using a model as the last stage without wrecking precision.</td><td><a href="llm-triage.md">llm-triage.md</a></td></tr><tr><td><strong>Research and datasets</strong></td><td>The paper corpus and the labeled ground-truth corpora.</td><td><a href="research-and-datasets.md">research-and-datasets.md</a></td></tr></tbody></table>

## Sources

* [A Benchmark Comparison of Python Malware Detection Approaches](https://arxiv.org/abs/2209.13288), arXiv:2209.13288 (Vu, Newman, Meyers, 2022). The 15–97% FP range.
* [An Empirical Study of Malicious Code in the PyPI Ecosystem](https://arxiv.org/abs/2309.11021), arXiv:2309.11021, ASE 2023. 4,669 malicious files; the 74.81% and 43.4% figures.
* [Small World with High Risks](https://arxiv.org/abs/1902.09217), arXiv:1902.09217, USENIX Security 2019. npm trust concentration.
* [LastPyMile](https://research.vu.nl/ws/portalfiles/portal/226504739/LastPyMile.pdf), Vu et al., ESEC/FSE 2021. Source-vs-artifact differential analysis.
* [PyPI incident report: LiteLLM/Telnyx](https://blog.pypi.org/posts/2026-04-02-incident-report-litellm-telnyx-supply-chain-attack/), official PyPI post-mortem, 2026-04-02.
* [Compromised LiteLLM PyPI package delivers multi-stage credential stealer](https://www.sonatype.com/blog/compromised-litellm-pypi-package-delivers-multi-stage-credential-stealer), Sonatype.
* [The Hades Campaign: memory scrapers and wipers via PyPI](https://www.stepsecurity.io/blog/the-hades-campaign-pypi-packages), StepSecurity.
* [Malicious packages across open-source registries, Q2 2025](https://www.fortinet.com/blog/threat-research/malicious-packages-across-open-source-registries), FortiGuard Labs.
* [Backstabber's Knife Collection](https://arxiv.org/abs/2005.09535), arXiv:2005.09535, DIMVA 2020.
* [Dependency Confusion](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610), Alex Birsan, Feb 2021.
