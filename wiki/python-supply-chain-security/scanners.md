---
description: The open-source and commercial package scanner landscape, what each one actually does internally, and how to layer them.
---

# Scanners

Two distinct jobs that get conflated. **Malware-focused** tools look for install hooks,
obfuscation, and exfiltration, intent. **Vulnerability-focused** tools look up known CVEs.
They aren't substitutes: a benign package can carry CVEs, and a package with a clean CVE
record can be malware. Deploy both.

Back to the [overview](README.md). Data feeds are on [Feeds](feeds.md).

## The short answer

For a local pre-install checker: **GuardDog** for the static and metadata layers,
**pip-audit** or **OSV-Scanner** for CVEs, **OpenSSF package-analysis** if you need dynamic
behavior, and skip the rest unless you have a specific reason.

## GuardDog (DataDog)

**Repo:** [DataDog/guarddog](https://github.com/DataDog/guarddog) · Python · Apache-2.0 ·
~1,165★ · v3.1.0 (July 2026), actively maintained. Releases land every few weeks, so read the
repo for the current version rather than trusting this line.

The default choice for the static layer, and the one tool here worth reusing rather than
reinventing: it is the detector behind the DataDog malicious-package dataset, and it is what the
published tool-vs-tool comparisons benchmark against
([arXiv:2603.27549](https://arxiv.org/abs/2603.27549)).

**Detection layers**

1. **Metadata heuristics**: Python detector modules over registry metadata: author, version
   history, release patterns, domain resurrection (maintainer email domain re-registered after
   release), missing info (no description, version `0.0.0`), typosquatting (Levenshtein ≤1
   against the top 5,000 packages, or exactly two characters swapped).
2. **Source code analysis**: YARA rules in `guarddog/analyzer/sourcecode/`, run in the main
   process behind a sandbox (network blocked, filesystem restricted to the extracted files).
   Semgrep was the engine through 2.x and was **removed in 3.0**: `yara-python` is the only rule
   engine now, and every rule ID was renamed. User-supplied rules are still supported.

**Rule inventory** (v3.1.0 ships 54 rule files in two families):

* `capability-*`, a capability with no judgement attached: `capability-filesystem-read`,
  `capability-filesystem-write-executable`, `capability-network-outbound`,
  `capability-network-download`, `capability-process-spawn`, `capability-runtime-clipboard` and
  similar.
* `threat-*`, a combination that is suspicious in itself:
  `threat-runtime-obfuscation-base64exec`, `threat-process-spawn-silent`,
  `threat-network-outbound-shady-links`, `threat-process-cryptomining`,
  `threat-setup-network-in-install`, `threat-network-reverse-shell`, and about forty more.

Each rule carries `severity`, `specificity`, `sophistication`, and MITRE-tactic metadata in its
`meta` block plus a `path_include` extension list. Rules are multi-language inside one file
(Python, JavaScript/TypeScript, Go, Ruby strings side by side), covering the ecosystems the tool
scans: PyPI, npm, Go modules, RubyGems, GitHub Actions, VSCode extensions.

Names change between major versions, so pin the rule IDs you depend on to a GuardDog version and
list the directory to confirm them.

**Design philosophy, worth internalizing:** *"Capability + threat together indicates actual
risk."* It deliberately avoids flagging suspicious patterns in isolation, which is the same
corroboration principle described on [Detection quality](detection-quality.md).

**CLI**

```bash
guarddog pypi scan <package-name>                      # latest version
guarddog pypi scan <package-name> --version X.Y.Z      # specific version
guarddog pypi scan /path/to/package.tar.gz             # local archive
guarddog pypi scan /path/to/directory                  # local source tree
guarddog pypi verify requirements.txt                  # audit a requirements file
guarddog pypi verify --output-format=sarif requirements.txt
```

Output: columnar text, JSON, or SARIF for CI. It sandboxes its own analysis using Landlock on
Linux and Seatbelt on macOS.

**Latency:** 0.5–2s per package.

**Known limitations.** Metadata heuristics are less precise than the code patterns and are the
main FP source. Historically it concentrates on `setup.py` to keep FPs down, so malware in
`__init__.py` or a lazily imported submodule can slip past. Its hardcoded patterns have a
[published bypass](https://medium.com/@heyyoad/how-we-evaded-datadogs-malicious-package-detection-lessons-for-better-security-e8c9b185f97e)
using f-string-assembled `__import__` calls. Static-only measurements put it around 40% FP /
60% TP, though those measurements predate the 3.0 rewrite of the ruleset.

Datadog also ships a **Supply Chain Firewall** that blocks installation of packages GuardDog
flags, if you want enforcement rather than reporting.

## packj (Ossillate)

**Repo:** [ossillate-inc/packj](https://github.com/ossillate-inc/packj) · Python · **AGPL-3.0**
· ~686★ · last release v0.15-beta (Feb 2023), repo active through April 2026

Risk *auditing* rather than pure malware detection. Strongest on the metadata dimension
GuardDog is weakest on.

**Layers**

1. **Metadata**: author email validity, maintainer domain expiration, release-history gaps
   (dormant packages), repository activity and cadence.
2. **Code behavior**: sensitive API usage (network, filesystem, process spawning),
   dependency graph analysis.
3. **Supply chain**: CVE matching, typosquat patterns, abandoned-package flags, provenance
   verification (declared repo vs packaged source).
4. **Dynamic tracing (optional)**: `strace` during installation, capturing syscalls made by
   install hooks.

**Risk categories** with configurable thresholds: author risk, maintenance risk, dependency
risk, code behavior risk.

**Ecosystems:** PyPI, npm, RubyGems, PHP/Packagist, .NET/NuGet, Java/Maven, Rust/Cargo (in
progress).

**Latency:** 1–5s per package; `strace` adds meaningful overhead.

**Caveats.** AGPL-3.0, modifications must be released, so think before embedding it in
anything you ship. Reported over 70 malicious PyPI and RubyGems packages to date.

## OpenSSF package-analysis

**Repo:** [ossf/package-analysis](https://github.com/ossf/package-analysis)

The dynamic layer, and the source of much of the OpenSSF malicious-packages feed.

**What it does:** downloads a package, executes it in a **gVisor** sandbox, and records
syscall traces (strace), network connections and DNS lookups, file access (read/write/delete),
processes spawned, and network packets with destinations and ports.

**Coverage:** 62.75% install success rate, 95.81% import success rate across the ecosystem;
PyPI coverage is among the highest.

**Where results go:** the public BigQuery dataset `ossf-malware-analysis`, table
`packages.all_packages` for metadata, `results.execution_result` for behavioral findings.
Optional publishing to your own bucket via `OSSF_MALWARE_ANALYSIS_RESULTS`.

**Running it locally**

```bash
scripts/run_analysis.sh -ecosystem pypi -package Django
scripts/run_analysis.sh -ecosystem pypi -package Django -version 4.1.3
scripts/run_analysis.sh -ecosystem pypi -local /path/to/test.whl
```

Container image `gcr.io/ossf-malware-analysis/analysis`. Needs `--privileged` and a
filesystem that supports nested gVisor sandboxing.

**Latency:** 5–30s per package.

**Interpretation.** Treat findings as a risk score, not a verdict. Installers legitimately
write to the home directory; dev tools legitimately enumerate files. The high-signal findings
are home-directory scraping, network beaconing, process injection, and obfuscated exec.

{% hint style="warning" %}
This is built for a fleet pipeline, not a laptop. It remains the closest open-source thing to
a usable dynamic sandbox for package analysis, and the absence of a lighter alternative is one
of the real gaps in this space.
{% endhint %}

## CVE scanners

Different job, known vulnerabilities, not malware, but you want one.

* **[pip-audit](https://github.com/pypa/pip-audit)**: PyPA, Apache-2.0, ~1,330★, actively
  released. Scans environments and requirements files against the PyPA advisory database, and
  can apply fixes automatically. The Python-native default.
* **[OSV-Scanner](https://github.com/google/osv-scanner)**: Google, Go, Apache-2.0,
  ~10,600★. Multi-ecosystem, backed by OSV. v2.3.5 (March 2026) added transitive resolution
  for Python `requirements.txt` via the deps.dev resolver library. Pick this if you're
  scanning more than Python.
* **[Safety](https://pypi.org/project/safety/)**: freemium; free tier over OSV data,
  commercial tier adds proprietary intelligence. Note the non-commercial license on the free
  database.

## The rest of the OSS landscape

**[Semgrep](https://github.com/semgrep/semgrep)**: OCaml engine, YAML rules. The engine
(`semgrep-oss`, what `pip install semgrep` gives you) is LGPL-2.1 and the community
[rules](https://github.com/semgrep/semgrep-rules) are open; the commercial parts are the Pro
engine's cross-file and cross-function analysis and the hosted platform. GuardDog 3.x no longer
uses it, so reach for Semgrep directly when you want taint-mode dataflow rules of your own,
which YARA cannot express.

**[Bandit](https://github.com/PyCQA/bandit)**: PyCQA, Apache-2.0, ~8,150★. SAST for
*insecure* code: hardcoded secrets, SQL injection, weak crypto, unsafe deserialization. It
assumes benign intent, so **it will not find a backdoor, an install hook, or a supply-chain
attack.** Useful as a complement, wrong tool for this job. (LastPyMile's "Bandit4mal" is a
malware-oriented rule fork of it.)

**[Aura](https://github.com/SourceCodeAI/aura)**: LGPL-3.0, ~200★. PyPI-specific: AST
analysis for dangerous functions, network access, file operations, import patterns, plus
behavioral analysis of metadata, dependency chains, and version history, with multi-factor
risk scoring. 0.5–2s per package, no sandboxing. Less mature than GuardDog; repo availability
has been intermittent.

**[OSSGadget](https://github.com/microsoft/ossgadget)**: Microsoft, C#/.NET, MIT, ~365★. A
toolkit: `oss-detect-backdoor`, `oss-characteristics` (Application Inspector),
`oss-defog` (base64 deobfuscation), `oss-find-squats`, `oss-health`,
`oss-risk-calculator`. Takes PURLs (`pkg:pypi/requests@2.28.1`). Measured at ~4.13s per
package with very broad matching (~4.26 flagged locations per package), and
`oss-detect-backdoor` is notoriously noisy. The .NET runtime is a heavy dependency for a
Python tool.

**YARA-based approaches**: YARA is the right engine for byte-pattern signatures (marshal
magic, zlib headers, encoded blobs). GuardDog 2.0 added it alongside Semgrep and 3.0 made it the
only source-code engine, which is the clearest signal of where this niche landed. `maloss` is the
experimental package-oriented YARA project; not production-ready.

**Not applicable:** oss-fuzz is a fuzzing service for maintainers finding bugs in their own
code, not a supply-chain detector. It comes up in searches; ignore it here.

## Commercial tools

| Tool | Malware detection | Notes |
|---|---|---|
| **[Socket.dev](https://socket.dev)** | Excellent | 70+ red flags (network access, shell execution, high-entropy strings, `eval`) plus an AI layer, SocketAI, measured at 90.95% accuracy. Its real edge is maintainer behavior analysis: unstable ownership, out-of-order version publishing. Known FP mode: flagging legitimate CLI tools that monitor keystrokes. |
| **[ReversingLabs Spectra](https://www.reversinglabs.com/products/spectra)** | Excellent | Built on malware-analysis expertise; file reputation, classification, dynamic analysis. Their `aiocpa` writeup is the reference case for behavioral sequence models beating static analysis. Expensive. |
| **[Phylum](https://phylum.io)** | Good | ML risk scoring learned from millions of packages; flags anomalies like a brand-new single-download package requesting env vars or spawning a shell. Operates as a package-manager firewall with detection at upload time. **Acquired by Veracode (2025)**, now their SCA "Package Firewall". |
| **[Snyk](https://snyk.io)** | Limited | Primarily CVE and license; behavioral analysis is thin. See [Feeds](feeds.md) for pricing. |
| **[Checkmarx SCS](https://checkmarx.com/)** | Limited | Enterprise supply-chain platform, known threats and anomalies. Their threat research on typosquat/starjacking campaigns is worth reading regardless. |
| **[Sonatype Nexus Intelligence](https://www.sonatype.com/)** | Limited | Component intelligence and risk scores, mostly CVE-driven. Their blog is a good incident source. |
| **JFrog Xray** | Moderate | Produces a "maliciousness score"; very high scores auto-flag, moderate ones route to human researchers. Explicitly tuned to suppress alert fatigue by ignoring low scores. |

## Layering recipe

<table><thead><tr><th width="70">Stage</th><th width="200">Tool</th><th width="110">Latency</th><th>Decision</th></tr></thead><tbody><tr><td>1</td><td>packj metadata scores, or your own heuristics</td><td>0.1–1s</td><td>Filter out popular, aged, well-maintained packages. Emit a 0–100 metadata risk score with a configurable threshold.</td></tr><tr><td>2</td><td>GuardDog (YARA source rules + metadata detectors)</td><td>0.5–2s</td><td>Any high-severity rule match escalates. Otherwise pass, or continue if the metadata score was high.</td></tr><tr><td>3</td><td>OpenSSF package-analysis (gVisor)</td><td>5–30s</td><td>Only on stage-2 hits. Pattern-match the trace against known IOCs: exfil to known C2, unexpected network, shell spawning.</td></tr><tr><td>4</td><td>LLM triage — see <a href="llm-triage.md">LLM triage</a></td><td>2–10s</td><td>Only on stage-3 findings plus the human queue. Structured output, evidence citations, never the only vote.</td></tr></tbody></table>

**Cost per 1,000 packages, single machine:** stage 1 is 100–1,000s and effectively free;
stage 2 is 500–2,000s (5–30 CPU-minutes, parallelizes linearly); stage 3 is 5,000–30,000s
(2–8 hours) and is the bottleneck, so it needs a queue or a thread pool; stage 4 you should be
running on tens of packages, not thousands.

**For a local embedded checker:** always run 1 and 2; run 3 only on static hits; run 4
offline and on demand.

## Verification notes and gaps

* GuardDog's rule inventory above was read off the v3.1.0 tree. It changes with every release and
  the IDs were renamed wholesale at 3.0, so list `guarddog/analyzer/sourcecode/` for the version
  you actually run instead of trusting a count or a name here.
* The ~40% FP / ~60% TP static figure quoted above predates 3.0 and measured the Semgrep-era
  ruleset, which no longer exists. No published measurement of the YARA ruleset was found.
* `pypi-scan` (IQT Labs) appears in older writeups; searches did not surface a current repo,
  so treat it as possibly deprecated.
* VirusTotal comes up as an option but requires a third-party service, so it is not embeddable
  in a local-only tool.
* Commercial free-tier boundaries change constantly. Verify pricing directly.

## Sources

* [GuardDog](https://github.com/DataDog/guarddog) · [GuardDog announcement](https://securitylabs.datadoghq.com/articles/guarddog-identify-malicious-pypi-packages/) · [GuardDog 2.0](https://securitylabs.datadoghq.com/articles/guarddog-2-0-release/) · [Supply Chain Firewall](https://securitylabs.datadoghq.com/articles/introducing-supply-chain-firewall/)
* [packj](https://github.com/ossillate-inc/packj)
* [OpenSSF package-analysis](https://github.com/ossf/package-analysis) · [BleepingComputer coverage](https://www.bleepingcomputer.com/news/security/open-source-package-analysis-tool-finds-malicious-npm-pypi-packages/)
* [pip-audit](https://github.com/pypa/pip-audit) · [OSV-Scanner](https://github.com/google/osv-scanner) · [Bandit](https://github.com/PyCQA/bandit)
* [Semgrep](https://github.com/semgrep/semgrep) · [semgrep-rules](https://github.com/semgrep/semgrep-rules)
* [Aura](https://github.com/SourceCodeAI/aura) · [OSSGadget](https://github.com/microsoft/ossgadget)
* [Socket.dev: surveillance malware hidden in npm and PyPI packages](https://socket.dev/blog/surveillance-malware-hidden-in-npm-and-pypi-packages)
* [Aikido: top tools to detect malware in dependencies](https://www.aikido.dev/blog/top-tools-to-detect-malware-in-dependencies), SocketAI accuracy comparison
* [Endor Labs: LLM-assisted malware review](https://www.endorlabs.com/learn/llm-assisted-malware-review-ai-and-humans-join-forces-to-combat-malware)
* [JFrog: how Xray avoids false positives](https://jfrog.com/blog/wolves-or-sheep-how-xray-avoids-false-positives-in-vulnerabilities-scans/)
* [How we evaded Datadog's malicious package detection](https://medium.com/@heyyoad/how-we-evaded-datadogs-malicious-package-detection-lessons-for-better-security-e8c9b185f97e)
* [Understanding npm malicious package detection: a benchmark-driven empirical analysis](https://arxiv.org/abs/2603.27549), arXiv:2603.27549, tool-vs-tool comparison
