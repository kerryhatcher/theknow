---
description: Why package malware scanners drown in false positives, how attackers evade every static rule, and a concrete confidence-scoring scheme.
---

# Detection quality

The part that decides whether a detector is usable or shelfware. Back to the
[overview](README.md).

## The false-positive crisis

{% hint style="danger" %}
Measured false-positive rates for Python malware detection tools run **15% to 97%**
([arXiv:2209.13288](https://arxiv.org/abs/2209.13288)). Raising thresholds to cut FPs collapses
the true-positive rate toward zero. PyPI administrators interviewed in that study said they
would need FP rates below **0.01%** to act on alerts.
{% endhint %}

Do the arithmetic. PyPI sees roughly 500,000 releases a month:

| FP rate | False alarms per month |
|---|---|
| 1% | 5,000 |
| 0.1% | 500 |
| 0.01% | 50 |

The same benchmark found PyPI's own native checks at ~78% FP with ~20% TP, worse than useless
at that ratio, and concluded that external security researchers were more effective than the
automated detection of the day. This is not an edge-case problem. It is *the* problem.

Compounding it: benchmark class balance is nothing like production, and the gap is bigger than
the usual framing admits. Counting *packages*, PyPI is roughly **70:1** benign to
catalogued-malicious. But a scanner does not see packages, it sees **releases**, and that is a
much harsher prior: roughly 6,000,000 releases a year (500,000 a month) against on the order of
1,000 newly catalogued malicious packages a year, if the ~10,000 known malicious accumulated
over about a decade. That puts the per-release base rate somewhere near **1 in 10,000**, two
orders of magnitude past 70:1.

Treat that as an estimate, not a measured figure: nobody publishes an authoritative annual
discovery rate, and the catalogue lags real uploads. Calibrate against the release base rate
regardless, because it is the reason the 0.01% FP bar above is arithmetic rather than paranoia.
Academic benchmarks downsample to 1:3 or 1:10, so published precision figures are optimistic
relative to production. See [Research and datasets](research-and-datasets.md#class-imbalance).

## Benchmark numbers

| Approach | FP | TP / recall | Note |
|---|---|---|---|
| PyPI native checks ([arXiv:2209.13288](https://arxiv.org/abs/2209.13288)) | 78% | ~20% | 15–97% range across the tools tested |
| GuardDog, static only | ~40% | ~60% | Bypassed by string concat + dynamic import |
| PYPILINE (LLM + static) | 3% (96.7% precision) | 99.6% recall (0.4% FN) | 8-category taxonomy, structured JSON output |
| PyFEX (forced execution) | n/a | 212 detections across 91.3k packages | Found malware the rules missed |
| LastPyMile (source vs artifact) | **<1%** | **~95%** | Analyzes only the diff — the best pair in the set |
| eDySec (eBPF dynamic) | −82% FP vs static | −79% FN vs static | 170ms inference per package |
| Socket AI layer | ~9% combined error (90.95% accuracy) | | Vendor-reported |
| Endor Labs, GPT-3.5 on whole packages | 15 FP against 13 TP, of 34 flagged out of 1,874 queried | 19 of the 34 judged correctly (56%) | Why the LLM goes last, not first |
| ConfuGuard (name attacks) | 80% → 28% reported FP | | 65% relative FP reduction over prior typosquat work |

Two conclusions fall out of that table. **Narrowing the input beats improving the rule** —
LastPyMile and taint-slicing both win by shrinking what gets analyzed. And **dynamic beats
static on both error types**, at a latency cost.

## Legitimate patterns that trip high-signal heuristics

`base64` + `exec` is not inherently malicious. It appears constantly in code you depend on:

* **Data serialization**: pickle plus base64 for ML model serving, Flask sessions, caches.
* **Build hooks**: legitimate C-extension compilation via `exec` in `setup.py`: numpy,
  cryptography, anything Cython-generated.
* **Cloud SDKs**: boto3, google-cloud-python, azure-identity read `~/.aws`, `~/.gcp`, and
  credential environment variables because that is their function.
* **Plugin systems**: pytest, Flask extensions, entry-point registries all use
  `__import__`/`importlib`/`getattr` dynamically.
* **Templating engines**: Jinja2 and Mako compile code at runtime by design.
* **Compression**: zlib or brotli decompression of embedded resources: fonts, prebuilt
  wheels, binary test fixtures.
* **Metadata oddities**: unusual version numbers, and deliberately obfuscated build scripts
  in projects with a commercial fork.

**What distinguishes the benign case:**

1. **Taint chain origin.** Data flows from a declared source (a static data file, `setup.py`
   itself, a config value), not from the network or the environment.
2. **Missing corroboration.** No network I/O, no credential read, no install hook running
   outside the build.
3. **Popularity prior.** scipy, scikit-learn, and requests have years of history. A
   zero-download upload from two days ago showing the same patterns does not.

## The evasion arms race

Everything here is documented post-2024. Every static rule described on this wiki has a
published bypass, which is why rule-based detection needs *maintenance*, not deployment.

### Multi-layer encoding and packing

* **Recursive base64 + zlib.** `aiocpa` (ReversingLabs, Nov 2024) embedded the payload as
  recursive Base64(zlib(code)) in the source file `utils/sync.py`, deobfuscating only at
  runtime. It was present only in the PyPI artifact, never in the GitHub repo.
* **Unicode homoglyphs.** `onyxproxy` (Phylum) used Cyrillic and Greek lookalikes so
  string-matching rules searching for `subprocess` never matched.
* **Minification.** Whitespace and comment removal to blunt static analysis and human review.

### Dynamic code dispatch

* **String concatenation in `__import__`.** Researchers evading GuardDog used
  `__import__(f'{chunk1}{chunk2}{chunk3}')` to spell `builtins` at runtime, sidestepping every
  hardcoded `socket`/`subprocess` pattern.
* **`getattr` chains.** `getattr(__builtins__, 'exec')(payload)`, or `__getattribute__` to
  reach a forbidden function indirectly.
* **Staged downloads.** The first published version is clean; a later version fetches the
  payload from C2 at import time. Whatever you scanned isn't what runs.

### Bytecode and compiled pivots

* **`.pyc`-only delivery.** Ship compiled bytecode with no source. Source-level static
  analysis has nothing to read; you need bytecode decompilation or forced execution.
* **Payloads inside model files.** A PyTorch checkpoint is a zip of pickles, so unpickling one
  on import is remote code execution. Any package that ships or fetches model weights carries
  this surface. No incident in this wiki's corpus is confirmed to have used it on PyPI, so treat
  it as an attack surface worth covering rather than a documented campaign.
* **Native extensions.** The W4SP campaign shipped compiled modules so Python static analysis
  never saw the payload at all.

### Sandbox and environment evasion

* **Geofencing**: check IP location, skip the payload outside the target region.
* **Sleep**: `time.sleep(86400)` outlasts any time-bounded sandbox.
* **CI/VM detection**: `/proc/cpuinfo`, `dmidecode`, container environment variables.
* **OS and user targeting**: `platform.system()`, `getpass.getuser()`, presence of specific
  developer tooling.
* **C2 availability check**: ping the C2 first and behave benignly if it's unreachable, which
  is exactly how a no-egress sandbox looks.

### Detection-aware obfuscation

* **Scan-scope awareness.** GuardDog concentrates on `setup.py` to hold FPs down, so payloads
  move to `__init__.py`, `utils.py`, or a lazily imported submodule.
* **Split payloads.** Malicious setup in one module, decoding in a second, C2 callback in a
  third, no single file looks bad.
* **Conditional burial.** `if __name__ != "__main__" and get_user() == "deploy": activate()`.
* **Differential semantics.** The repo stays clean; the payload exists only in the built
  wheel, via CI compromise or a direct `twine upload`. See
  [repo-vs-artifact divergence](name-attacks.md#repo-vs-artifact-divergence).
* **LLM-targeted README optimization (PromptMink).** Craft the README with authority signals
  ("built by", "trusted by") so an LLM-driven dependency resolver prefers the malicious package
  over the real one. A genuinely new attack surface.

### The structural problem

**Static analysis identifies calls, not intent.** A call to `exec()` is byte-identical in a
benign plugin loader and in a stealer. Attackers know this, which is why the credible answers
are all about *context*: behavioral sequences, differential analysis, or forced execution, not
better pattern lists.

## Confidence scoring

Tiered signals with mandatory corroboration. This is the scheme to implement.

### Signal tiers

<table><thead><tr><th width="80">Tier</th><th width="240">Signal class</th><th width="90">Weight</th><th>Examples</th></tr></thead><tbody><tr><td>1</td><td>Installation-time code execution</td><td>5</td><td><code>exec</code>/<code>compile</code>/subprocess in <code>setup.py</code>; install hooks that download files</td></tr><tr><td>2</td><td>Encoding and obfuscation</td><td>3</td><td>Encoding plus decode-and-exec; homoglyphs; minified code</td></tr><tr><td>3</td><td>Network or credential access</td><td>3, or <strong>1</strong> in an SDK that legitimately needs credentials</td><td>Imports <code>socket</code>/<code>urllib</code>/<code>requests</code> with no plausible use; reads <code>~/.aws</code>, <code>~/.ssh</code>, secret env vars</td></tr><tr><td>4</td><td>Unusual metadata or behavior</td><td>1</td><td>Zero downloads; new account; mismatched versions; README crafted for LLM parsing; source ≠ wheel</td></tr><tr><td>5</td><td>Sandbox evasion</td><td>1</td><td>Sleep, geofencing, CI/container detection. Almost never benign, never sufficient alone</td></tr></tbody></table>

### Algorithm

1. Gather signals across all tiers.
2. Sum the weights. **Each tier contributes its weight at most once**, however many signals
   fire inside it. Two Tier 2 hits (say obfuscation plus minified code) still score 3, not 6.
3. Apply the band:
   * **0–2 points**: LOW. Informational; no action.
   * **3–5 points**: MEDIUM. Human review.
   * **6+ points**: HIGH. Block or quarantine.

The per-tier cap is what makes the corroboration rule automatic rather than a second rule to
enforce separately: the largest score any single tier can produce is 5 (Tier 1), so **6+ points
is only reachable by crossing tiers**. A pile of signals inside one tier can never block on its
own.

### Corroboration matrix

Worked examples, derived from the weights and bands above rather than stated independently. If
you change a weight, recompute this table.

| Combination | Points | Verdict and reasoning |
|---|---|---|
| Tier 3 only (SDK creds, weight 1) | 1 | LOW. Credentials read, but sent anywhere? |
| Tier 2 only | 3 | MEDIUM. Encoding is present, but is the decode-and-exec in the same function? |
| Tier 4 + Tier 3 | 4 | MEDIUM. A new package reading credentials; needs an exec or exfil path to escalate |
| Tier 5 + Tier 3 | 4 | MEDIUM. Evasion plus credential access; go looking for the sink |
| Tier 1 only | 5 | MEDIUM. Review the code path; may be a Cython or cffi build |
| **Tier 2 + Tier 3** | **6** | **HIGH.** Obfuscated code that reads secrets and connects out |
| **Tier 4 + Tier 1** | **6** | **HIGH.** A new package executing code at install time |
| **Tier 5 + Tier 1** | **6** | **HIGH.** Evasion plus install-time execution means a targeted attack |
| **Tier 1 + Tier 2** | **8** | **HIGH.** Obfuscated code executing during install: the LiteLLM shape |
| **Tier 1 + Tier 3** | **8** | **HIGH.** An install hook that exfiltrates credentials |

### Contextual allowlists

The other half of precision. Without these, the scheme still drowns you.

**Package-level**

* Popularity suppresses **Tier 4 metadata signals only**. A top-1,000 package is not a new
  account with zero downloads, so those signals carry no information about it.
* **Never discount Tier 1, 2, or 3 on download count.** A compromised popular package is the
  highest-impact case, not the lowest-risk one, and account takeover happens *because* the
  package is popular. LiteLLM shipped a `.pth` install hook (Tier 1) containing base64-obfuscated
  code (Tier 2) while sitting well above 1M downloads: 8 points, HIGH. Any popularity rule that
  discounts that pair would have filed the biggest incident of 2026 as informational.
* Where a source repo is known, the repo-vs-artifact diff supersedes popularity entirely. A
  popular package whose wheel diverges from its repo escalates regardless of downloads.

**Pattern-level**

* `setup.py` + `exec` where a known build idiom is present (`from Cython.Build import
  cythonize` or equivalent): allowlist.
* Cloud SDKs (boto3, google-cloud-*, azure-*, gcp-auth): allowlist credential reads from
  standard paths.
* Serialization: allowlist `pickle`/`dill` imports where the deserialized object is processed
  rather than `exec`'d.

### Differential tiers

Always compare source repo to built artifact where a repo is known:

* Repo clean, wheel contains obfuscated code → **HIGH** (likely post-publish compromise).
* Identical → benign build process.
* Wheel has fewer lines than source → possibly minification; MEDIUM if paired with Tier 2/3.

## Design rules

1. **Never block on a single tier.** A blocking verdict needs signals from 2+ tiers, which the
   per-tier cap enforces arithmetically. A single tier can still earn MEDIUM and a human look,
   as the matrix above shows; what it must never do on its own is quarantine a package.
2. **Allowlist deliberately.** Build-system idioms and cloud-SDK credential reads, and popularity
   for metadata signals only, never to discount install-time execution or obfuscation.
3. **Use differential analysis.** Source versus published artifact; a mismatch is the
   highest-precision signal available.
4. **Combine static and dynamic.** Forced execution (the PyFEX pattern) catches runtime
   obfuscation that static analysis structurally cannot.
5. **Model behavioral sequences, not calls.** Not "is `exec` present" but "do exec, network,
   and credential read happen in sequence".
6. **If you use an LLM, demand structured output.** The PYPILINE pattern: explicit categories
   (install hooks, obfuscation, exfil paths, sandbox evasion) with evidence. See
   [LLM triage](llm-triage.md).
7. **Track the arms race explicitly.** Keep a running log of newly published evasion
   techniques and revisit rules quarterly. Every technique on this page was novel once.
8. **Log what you didn't check.** A silent top-N cap or a skipped stage reads as "clean" when
   it means "unexamined".

## Sources

* [A benchmark comparison of Python malware detection approaches](https://arxiv.org/abs/2209.13288), arXiv:2209.13288 (the 15–97% range and the 0.01% admin threshold)
* [Bad Snakes: understanding and improving Python Package Index malware scanning](https://dl.acm.org/doi/abs/10.1109/ICSE48619.2023.00052), ICSE 2023, the follow-up
* [PyFEX: forced execution for evasive threat discovery](https://arxiv.org/html/2606.02196), arXiv:2606.02196
* [PYPILINE: malicious PyPI package detection via suspicious API knowledge and agent workflow](https://arxiv.org/html/2606.19063v3), arXiv:2606.19063
* [eDySec: explainable dynamic analysis for PyPI](https://arxiv.org/abs/2604.26219), arXiv:2604.26219
* [DySec: ML-based dynamic analysis for PyPI](https://arxiv.org/pdf/2503.00324), arXiv:2503.00324
* [LastPyMile](https://research.vu.nl/ws/portalfiles/portal/226504739/LastPyMile.pdf), Vu et al., ESEC/FSE 2021
* [ConfuGuard](https://arxiv.org/abs/2502.20528), arXiv:2502.20528, USENIX Security 2025
* [How we evaded Datadog's malicious package detection](https://medium.com/@heyyoad/how-we-evaded-datadogs-malicious-package-detection-lessons-for-better-security-e8c9b185f97e), the `__import__` bypass
* [aiocpa infostealer analysis](https://www.reversinglabs.com/blog/malicious-pypi-crypto-pay-package-aiocpa-implants-infostealer-code), ReversingLabs
* [Python info-stealing malware uses Unicode to evade detection](https://www.bleepingcomputer.com/news/security/python-info-stealing-malware-uses-unicode-to-evade-detection/), Phylum's `onyxproxy`, via BleepingComputer
* [Malicious PyPI user strikes again](https://checkmarx.com/blog/malicious-pypi-user-strikes-again-with-typosquatting-starjacking-and-unpacks-tailor-made-malware-written-in-c/), Checkmarx on multi-stage CI/CD attacks
* [Endor Labs: LLM-assisted malware review](https://www.endorlabs.com/learn/llm-assisted-malware-review-ai-and-humans-join-forces-to-combat-malware), the 56% accuracy finding
* [Towards robust detection of OSS supply chain poisoning in industry environments](https://arxiv.org/pdf/2409.09356), arXiv:2409.09356
