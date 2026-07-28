---
description: The paper corpus behind this topic and the labeled malicious-package datasets you can train or benchmark against.
---

# Research and datasets

Where the numbers on the rest of these pages come from, and where to get ground truth if you
want to measure something yourself. Back to the [overview](README.md).

## The paper corpus

32 works: 28 arXiv papers plus 4 non-arXiv (the EuroS&P typosquatting paper, py2src,
LastPyMile, and Bad Snakes). Grouped by what they contribute.

### Characterization and measurement

| Paper | Venue | ID | Contribution |
|---|---|---|---|
| Backstabber's Knife Collection (Ohm, Plate, Sykosch, Meier) | DIMVA 2020 | [2005.09535](https://arxiv.org/abs/2005.09535) | 174 curated real malicious packages across npm/PyPI/RubyGems, Nov 2015–Nov 2019. Attack-tree taxonomy. The foundational corpus |
| An Empirical Study of Malicious Code in the PyPI Ecosystem (Guo et al.) | ASE 2023 | [2309.11021](https://arxiv.org/abs/2309.11021) | 4,669 malicious files, five behavior categories, >50% show multiple behaviors. **74.81% reach user projects; >72% persist on mirrors after discovery; 43.4% use obfuscation** |
| Small World with High Risks (Zimmermann, Staicu, Tenny, Pradel) | USENIX Security 2019 | [1902.09217](https://arxiv.org/abs/1902.09217) | npm maintainer concentration: an average install implicitly trusts ~79 packages and ~39 maintainers. No PyPI replication exists |
| Towards Measuring Supply Chain Attacks on Package Managers (Duan et al.) | NDSS 2021 | [2002.01139](https://arxiv.org/abs/2002.01139) | The MalOSS methodology. 339 malicious packages identified, 278 removed (82%); 3 with >100k downloads |
| I Know What You Imported Last Summer (Bagmar et al.) | 2021 | [2102.06301](https://arxiv.org/abs/2102.06301) | Import-based threat analysis for the Python ecosystem |
| An Analysis of Malicious Packages in OSS in the Wild (Zhou et al.) | 2024 | [2404.04991](https://arxiv.org/abs/2404.04991) | Knowledge-graph view of propagation. Largest malicious subgraphs: PyPI 950 nodes, npm 232, RubyGems 34 |
| Unveiling Malicious Logic (statement-level taxonomy) | 2025 | [2512.12559](https://arxiv.org/html/2512.12559v1) | **47 malicious indicators in 7 categories** (execution stage, execution mechanism, exfiltration, system impact, network operations, defense evasion, metadata manipulation), annotated at statement level |

### Static analysis and metadata

| Paper | Venue | ID | Contribution |
|---|---|---|---|
| Practical Automated Detection of Malicious npm Packages — Amalfi (Sejfia, Schäfer) | ICSE 2022 | [2202.13953](https://arxiv.org/abs/2202.13953) | Classifiers + reproducibility verification + clone detection, seconds per package. 95 previously unknown malicious found in 96,287 versions |
| Cross-Language Detection of Malicious Packages (Ladisa et al.) | ACSAC 2023 | [2310.09571](https://arxiv.org/abs/2310.09571) | **141 language-independent static features** (install scripts, obfuscated strings, URLs). One model over both registries found 58 unknown malicious (38 npm, 20 PyPI) in 31,292 packages |
| ConfuGuard / TypoSmart (Jiang, Çakar, Lysenko, Davis) | USENIX Security 2025 | [2502.20528](https://arxiv.org/abs/2502.20528) | Fine-tuned name embeddings + metadata FP suppression. Reported FPs 80% → 28%, a 65% relative reduction |
| Typosquatting and Combosquatting Attacks on the Python Ecosystem (Vu et al.) | EuroS&P Workshops 2020 | [PDF](https://conferences.computer.org/eurosp/pdfs/EuroSPW2020-7k9FlVRX4z43j4uE2SeXU0/859700a508/859700a508.pdf) | The string-similarity baseline for name attacks |
| py2src (Duc-Ly Vu) | ASE 2021 | [repo](https://github.com/simonepirocca/py2src) | Infers the real GitHub source for a PyPI package with a −4 to +4 reliability score. Prerequisite for differential analysis. Single-author paper per the DOI, DBLP and Semantic Scholar records; the tool repo sits under a different GitHub account, which is where citations listing extra authors come from |
| LastPyMile (Vu, Massacci, Pashchenko, Plate, Sabetta) | ESEC/FSE 2021 | [PDF](https://research.vu.nl/ws/portalfiles/portal/226504739/LastPyMile.pdf) | Source-vs-artifact differential analysis. Validated on 3 malicious plus 3 benign artifacts: all malicious ones detected, scanner alerts on them cut by one to two orders of magnitude, zero alerts on the benign ones. The paper reports no precision or recall figure |
| One Detector Fits All (Montaruli et al.) | ACSAC 2025 | [2512.04338](https://arxiv.org/abs/2512.04338) | Robust adaptive detection generalizing from PyPI to enterprise settings |

### Behavior sequences and ML

| Paper | Venue | ID | Contribution |
|---|---|---|---|
| Killing Two Birds with One Stone — Cerebro (Zhang et al.) | TOSEM 2024 | [2309.02637](https://arxiv.org/abs/2309.02637) | Fine-tuned BERT over abstracted behavior sequences. Found 306 new malicious PyPI and 196 npm packages live (Mar–Oct 2023) |
| DONAPI (Huang et al.) | USENIX Security 2024 | [2403.08334](https://arxiv.org/abs/2403.08334) | Behavior-sequence knowledge mapping; sequence ordering as obfuscation resistance |
| MalGuard (Gao et al.) | 2025 | [2506.14466](https://arxiv.org/abs/2506.14466) | Real-time detection off the PyPI upload feed. Flagged 144 suspicious packages in five weeks |
| Cutting the Gordian Knot (Guo et al.) | USENIX Security 2026 | [2601.16463](https://arxiv.org/abs/2601.16463) | Knowledge-mining across obfuscation patterns, suspicious APIs, naming anomalies, metadata inconsistencies, behavioral signatures. Multi-signal beats single-indicator |
| Towards Robust Detection of OSS Supply Chain Poisoning in Industry | ASE 2024 | [2409.09356](https://arxiv.org/abs/2409.09356) | Deployment realities in enterprise CI/CD; continuous monitoring |

### Dynamic analysis

| Paper | Venue | ID | Contribution |
|---|---|---|---|
| eDySec | 2026 | [2604.26219](https://arxiv.org/abs/2604.26219) | **eBPF** syscall/network/file monitoring during and after install. 50% feature-dimension reduction, **82% fewer FPs and 79% fewer FNs than static**, 170ms inference |
| DySec | 2025 | [2503.00324](https://arxiv.org/abs/2503.00324) | ML over sandboxed runtime behavior; catches runtime evasion and dynamic payloads |
| PyFEX | 2026 | [2606.02196](https://arxiv.org/html/2606.02196) | **Forced execution.** 212 previously unknown malicious packages found in live PyPI deployment, together accounting for 91,648+ downloads, that rules missed |

### LLM-based

| Paper | Venue | ID | Contribution |
|---|---|---|---|
| Leveraging LLMs to Detect npm Malicious Packages (Zahan et al.) | 2024 | [2403.12196](https://arxiv.org/abs/2403.12196) | GPT-4 at 99% precision / 97% F1 vs CodeQL 83% / 88%. Static pre-screening cut the file set 77.9% and cost 60–76% |
| Detecting Malicious Source Code in PyPI Packages with LLMs (Ibiyo et al.) | 2025 | [2504.13769](https://arxiv.org/abs/2504.13769) | Few-shot at 97% accuracy; **RAG underperformed** on weak retrieval and hallucination |
| Taint-Based Code Slicing for LLM Detection (Nguyen et al.) | 2025 | [2512.12313](https://arxiv.org/abs/2512.12313) | 87.04% vs 75.41% accuracy; 99.4% input reduction keeping 73.7% of malicious signal |
| PYPILINE (Pang et al.) | 2026 | [2606.19063](https://arxiv.org/html/2606.19063v3) | Suspicious-API knowledge plus agent workflow. **96.7% precision, 99.6% recall**, 8-category structured output |
| RMCBench (Chen et al.) | 2024 | [2409.15154](https://arxiv.org/abs/2409.15154) | LLM refusal rates on malicious code: 28.71% average, 11.52% code-to-code |
| ShadowCode (Yang et al.) | 2024 | [2407.09164](https://arxiv.org/abs/2407.09164) | Automated external prompt injection against code LLMs |
| cAST (Zhang et al.) | 2025 | [2506.15655](https://arxiv.org/abs/2506.15655) | AST-structural chunking for code retrieval |

### Benchmarking

| Paper | Venue | ID | Contribution |
|---|---|---|---|
| A Benchmark Comparison of Python Malware Detection Approaches (Vu, Newman, Meyers) | 2022 | [2209.13288](https://arxiv.org/abs/2209.13288) | **The 15–97% FP range.** PyPI native checks at 78% FP / 20% TP. Maintainer interviews put the acceptable FP bar at 0.01% |
| Bad Snakes (Vu, Newman, Meyers) | ICSE 2023 | [DOI](https://dl.acm.org/doi/abs/10.1109/ICSE48619.2023.00052) | The follow-up: deployment feasibility and proposed refinements. Artifacts on GitHub/Zenodo |
| Understanding npm Malicious Package Detection | 2026 | [2603.27549](https://arxiv.org/abs/2603.27549) | Tool-vs-tool comparison across OSSGadget, GuardDog, Amalfi |

### Consensus across the corpus

1. **The FP/FN trade-off dominates.** Every static approach reports FP rates that would swamp a
   real registry, and cutting FPs degrades TPs.
2. **Obfuscation is the norm, not the exception.** 43.4% of malicious packages use it. Entropy
   anomaly detection works but only partly.
3. **Real-time means sub-second.** PyPI and npm take thousands of uploads a day; a detector that
   takes a minute per package can't sit in the pipeline.
4. **Cross-language features generalize.** Install scripts, obfuscated strings, and URLs are
   ecosystem-independent enough for one model to serve npm and PyPI.
5. **Narrowing the input beats sharpening the rule.** LastPyMile (diff only) and taint slicing
   (99.4% reduction) both win by analyzing less. LastPyMile's reported result is the collapse in
   alert volume, not a measured precision figure.
6. **Trend since 2024:** LLM integration (97–99% F1 in the best studies, but see the Endor Labs
   counterexample on [LLM triage](llm-triage.md)), explainability for security-ops review,
   kernel-level instrumentation via eBPF, and graph-based propagation modeling.

## Labeled datasets

### OpenSSF `ossf/malicious-packages`

[github.com/ossf/malicious-packages](https://github.com/ossf/malicious-packages)

* **Size:** 16,272+ reports as of 2025, growing; npm, PyPI, RubyGems, crates.io
* **Format:** OSV JSON. Machine-readable, consumable through the OSV API, osv-scanner, deps.dev
* **Access:** public clone, no auth. Bulk imports accepted by PR or issue-triggered S3/GCS hookup
* **License:** Apache-2.0
* **Freshness:** daily
* **Safety:** metadata only, no live samples. Safe to archive and search
* **Verdict:** start here. Largest, best maintained, standardized, and it drops straight into
  tooling you already have

Trade-off: metadata-centric, so no source code to train on, behavior descriptions vary in
detail, and entries from automated feeds carry some false positives.

### DataDog `malicious-software-packages-dataset`

[github.com/DataDog/malicious-software-packages-dataset](https://github.com/DataDog/malicious-software-packages-dataset)

* **Size:** PyPI 1,965 (35%), npm 3,611 (64%), plus IDE extensions and AI skills, categorized
  "compromised" vs "with malicious intent". Secondary sources quote wildly different *totals*
  for this dataset (27,876 and 28,623 both appear, neither consistent with the per-ecosystem
  counts above), so read the repo's own manifest rather than trusting a headline number
* **Format:** encrypted ZIPs per ecosystem with a `manifest.json`; complete source once
  extracted. Use the provided `extract.sh`
* **Access:** public clone; samples in `samples/`, **password `infected`**
* **License:** Apache-2.0 for the dataset; samples keep their original package licenses
* **Freshness:** incremental, reflecting GuardDog detections
* **Verdict:** highest-quality ground truth, because it's human-triaged, and it ships real source

Trade-off: biased toward GuardDog's rules (so it can't fairly benchmark GuardDog), and the
decryption step is manual.

Contact: `securitylabs@datadoghq.com`

### `lxyeternal/pypi_malregistry`

[github.com/lxyeternal/pypi_malregistry](https://github.com/lxyeternal/pypi_malregistry)

* **Size:** 10,823 package versions across 9,503 unique malicious PyPI packages, including 3,327
  discovered and removed early plus 160+ newly detected
* **Format:** `<package>/<version>/<archive>`, tar.gz or zip, browsable on GitHub
* **Access:** public clone, no auth
* **License:** not explicitly stated, appears research-only. Check before any commercial use
* **Freshness:** updated through June 2026
* **Safety:** **not encrypted. Live malware, in git history. Treat as hostile**
* **Verdict:** the most comprehensive PyPI-only corpus. Derived from the ASE 2023 paper, with
  false positives manually removed

### Backstabber's Knife Collection

[Project site](https://dasfreak.github.io/Backstabbers-Knife-Collection/) ·
[repo](https://github.com/cybertier/Backstabbers-Knife-Collection)

* **Size:** 174 packages. npm 109 (62.6%), RubyGems 37 (21.3%), PyPI 28 (16.1%). Nov 2015–Nov 2019
* **Access:** **restricted.** Email `ohm[at]cs.uni-bonn.de` from an institutional address with a
  research proposal and GitHub username. No public download
* **Verdict:** peer-reviewed (DIMVA 2020) with attack-tree taxonomy and trigger-timing metadata,
  but small, stale, and thin on PyPI

### MalwareBench

[github.com/MalwareBench](https://github.com/MalwareBench)

* **Size:** 20,792 packages: 6,659 malicious, 14,133 benign, a 1:2.1 ratio built for ML
* **Access:** public repos, but a Google Form gate for the sample data
* **License:** MIT
* **Freshness:** last updated May 2024
* **Verdict:** the balanced-split option for training. Exact PyPI-vs-npm breakdown isn't published

### Statement-level taxonomy dataset

From [arXiv:2512.12559](https://arxiv.org/html/2512.12559v1)

* **Size:** 370 malicious PyPI packages, 833 files, 90,527 lines, **2,962 labeled occurrences**
  of 47 malicious indicators across 7 categories
* **Format:** statement-level annotations mapping code lines to behaviors
* **Access:** the paper states it will be public; no repository URL confirmed yet
* **Verdict:** the finest-grained annotation available, which makes it the right corpus for
  training something beyond binary classification. Malicious-only, so bring your own benign set

## Class imbalance

Counting packages, real PyPI runs roughly **70:1 benign to malicious** (717,280+ packages
against 10,000+ known malicious). Academic benchmarks don't reproduce that:

| Benchmark | Malicious | Benign | Ratio |
|---|---|---|---|
| MalwareBench | 6,659 | 14,133 | 1:2.1 |
| Cross-language study | 2,314 | 7,391 | 1:3.2 |
| Python-specific ML evaluation | 168 | 1,430–2,416 | 1:8.5 to 1:14.4 |
| npm/PyPI behavior-annotated | 6,420 | 7,288 | 0.88:1 |
| Common recommendation | — | — | 1:10 |

Researchers downsample or stratify to 1:3–1:10 because a true 70:1 split is computationally
awkward and distorts metrics. The consequence matters: **published precision figures are
optimistic relative to production.**

And 70:1 is the *package-count* ratio, not the prior a live detector faces. A scanner sits on the
release stream: roughly 6,000,000 releases a year against on the order of 1,000 newly catalogued
malicious packages a year, which is a per-release base rate nearer **1 in 6,000**. That figure is
an estimate derived from the numbers on this page rather than a measured one, and it divides
releases by malicious *packages*, while a malicious package often ships several releases, so the
true rate skews lower still. Treat the order of magnitude, not the digits, as the finding. Calibrate thresholds against the release rate
either way, because false-positive rate becomes the metric that decides whether the tool ships.

## Handling live malware safely

{% hint style="danger" %}
`lxyeternal/pypi_malregistry` and the extracted DataDog samples are working malware. Several of
these packages execute on install or on import; that is the whole point of them.
{% endhint %}

1. **Isolate.** Analyze in a dedicated VM or container, never on a shared or production machine,
   and never in an environment with credentials worth stealing.
2. **Never install.** Read archives; don't `pip install` them. If you must execute, use a
   sandbox with no egress (gVisor, as OpenSSF Package Analysis does).
3. **Know what's defanged.** OSV metadata is safe. DataDog samples are encrypted at rest with
   password `infected` and unencrypted once extracted. `pypi_malregistry` is live in git history.
   Backstabber's relies on access gating rather than technical defanging.
4. **Monitor rather than trust.** Run under dynamic analysis instrumentation if you execute
   anything at all.
5. **Clean up.** Delete archives and extracted trees promptly, and never commit samples into a
   repository, you'd be republishing malware.

## Open questions

* Cross-dataset overlap between OpenSSF, DataDog, `pypi_malregistry`, and the academic
  benchmarks is unquantified, so "unique coverage" claims are unverifiable right now.
* Exact train/test splits and stratification methods per paper need confirming from the papers
  themselves.
* Availability of the statement-level taxonomy dataset is still unconfirmed.
* No malicious-*package* corpora were found on Hugging Face; the hits there are malicious
  *models*, which is a different threat.

## Sources

* [OpenSSF malicious-packages](https://github.com/ossf/malicious-packages) · [introduction post](https://openssf.org/blog/2023/10/12/introducing-openssfs-malicious-packages-repository/)
* [DataDog malicious-software-packages-dataset](https://github.com/DataDog/malicious-software-packages-dataset)
* [lxyeternal/pypi_malregistry](https://github.com/lxyeternal/pypi_malregistry)
* [Backstabber's Knife Collection](https://github.com/cybertier/Backstabbers-Knife-Collection) · [project site](https://dasfreak.github.io/Backstabbers-Knife-Collection/)
* [MalwareBench](https://github.com/MalwareBench)
* [An Empirical Study of Malicious Code in the PyPI Ecosystem](https://arxiv.org/pdf/2309.11021), the source of `pypi_malregistry`
* [Unveiling Malicious Logic: statement-level taxonomy and dataset](https://arxiv.org/html/2512.12559v1)
* Every arXiv ID in the tables above resolves: 28 distinct IDs, plus the four non-arXiv works
  (LastPyMile, the EuroS&P typosquatting paper, py2src, and Bad Snakes).
