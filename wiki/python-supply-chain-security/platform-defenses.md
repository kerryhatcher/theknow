---
description: What PyPI, PyPA, and OpenSSF actually ship as supply-chain defenses, what's still proposed, and which signals you can query.
---

# Platform defenses

The signals you get for free because someone else runs infrastructure. Some are strong and
queryable, several are strong and *not* queryable, and a couple that get cited constantly have
never shipped. Back to the [overview](README.md).

## Status at a glance

| Defense | Status | Queryable? |
|---|---|---|
| 2FA mandate | **Shipped** — enforced for all users since 2024-01-01, for browser account actions only, *not* for uploads | No public API |
| Trusted Publishing (OIDC) | **Shipped** 2023 — GitHub, GitLab, Google Cloud, ActiveState | Admin-side metadata only |
| PEP 740 attestations | **Shipped** Nov 2024 — 132,360+ packages; ~5% of the top 360 | **Yes** — per-file `provenance` URL in the Simple API JSON, served from `/integrity/.../provenance` |
| Project Quarantine | **Shipped** 2024 | No endpoint; inferred from install failure |
| OpenSSF Scorecard | **Shipped** 2020+, weekly precomputed | **Yes** — REST API and deps.dev |
| OpenSSF Package Analysis | **Shipped**, production, continuous | **Yes** — public BigQuery |
| OpenSSF malicious-packages | **Shipped**, OSV format, daily | **Yes** — OSV API |
| Sigstore keyless signing | **Shipped/mature** — CPython 3.11+ signed; PyPI integration in progress | Partial |
| SLSA Level 2/3 provenance | **Shipped** on GitHub Actions; PyPI adoption low | Partial |
| PEP 458/480 (TUF for PyPI) | **458 Accepted but unimplemented since 2019; 480 still Draft.** No ship date | n/a |

## Project Quarantine

Introduced in 2024, replacing binary removal with a reversible state. The flow: PyPI receives
a report through the "Report project as malware" button (added 2024); trusted reporters carry
extra weight and can trigger automated quarantine; administrators then clear it (false
positive), re-quarantine, or remove permanently.

**Response times, from the 2026 incidents**

| Package | Timeline |
|---|---|
| LiteLLM (2026-03-24) | 1h19m to first report, 1h12m report-to-quarantine, 2h32m total exposure, ~119,000 downloads inside it |
| Telnyx (same day) | 1h45m to first report, 1h57m report-to-quarantine, 3h42m total |

Since August 2023, PyPI has resolved over 90% of malware reports within 24 hours, a large
improvement over the pre-quarantine era when a malicious package could sit for weeks.

**How to observe it.** There is no endpoint. A quarantined project's metadata still resolves
but installation fails. And PyPI does not publicly distinguish administrative removal from
maintainer deletion, so absence alone doesn't tell you cause. Combine with the OpenSSF
malicious feed to separate malice from abandonment.

## Trusted Publishing and attestations

### Trusted Publishing (OIDC)

Publish without long-lived credentials. You register a publisher on PyPI naming the CI
provider, repository, and workflow file. At release time the CI requests a short-lived OIDC
token carrying signed claims (repo identity, workflow, branch/tag); PyPI verifies it and issues
a temporary upload token. Nothing durable is stored anywhere a thief can reach.

Providers as of 2026: GitHub, GitLab, Google Cloud, ActiveState, with more coming through the
OpenSSF Securing Software Repositories working group.

**Why it matters here:** this is the direct mitigation for the account-takeover pattern behind
LiteLLM and `durabletask`. A stolen token or password is no longer sufficient to publish.

**Queryability:** it's admin-side project metadata, not exposed in the public API. You can
often infer it from a valid PEP 740 attestation whose signing identity is a CI workflow.

### PEP 740 digital attestations

Shipped **November 2024**. Cryptographically signed attestations bundled with a release:
in-toto statements (filename plus SHA-256 digest) signed with ECDSA P-256 and DSSE encoding.
Each attestation carries the signature, the signing X.509 certificate, and transparency-log
entries corroborating certificate validity.

Distributed through the Simple Index, not the `/pypi/<package>/json` endpoint (which carries no
provenance field at all). In the Simple API JSON each file entry carries a `provenance` URL;
fetch that URL, of the form `https://pypi.org/integrity/<name>/<version>/<filename>/provenance`,
to get the attestation bundle. The HTML form of the Simple Index exposes the same thing as
`data-provenance`.

**Adoption as of March 2026:** 132,360+ packages have attestations. Of the top 360
most-downloaded packages, about **5%** do. Opt-in, driven by early adopters. Trail of Bits
tracks this at [Are we PEP 740 yet?](https://trailofbits.github.io/are-we-pep740-yet/).

**Verification steps**

1. Cryptographic suite is valid (ECDSA P-256 + SHA-256).
2. Certificate authenticates against trusted roots (currently the Sigstore public-good root CA).
3. Signature matches the certificate.
4. The package digest matches the statement binding.
5. Optionally, the signing identity corresponds to a registered Trusted Publisher.

**Interpretation.** A valid attestation proves the artifact was signed by a known identity and
hasn't been altered since. Absence proves nothing. Most legitimate packages still don't have
one, so you cannot treat "no attestation" as a risk signal without blocking most of PyPI.

## 2FA mandate

Fully enforced since **2024-01-01**, and narrower than it sounds. Every account needs TOTP or
WebAuthn for account actions performed **in the browser**: login, project transfers, permission
changes, and creating API tokens.

**It does not gate uploads.** There is no second-factor challenge on the publish path. An account
with 2FA enabled must upload using an API token or a Trusted Publisher configuration *in place of*
its password, so a stolen token publishes a release with no second factor involved
([PyPI's own announcement](https://blog.pypi.org/posts/2023-06-01-2fa-enforcement-for-upload/)).
That is exactly how LiteLLM and `durabletask` were pushed by `twine` more than two years after the
mandate. The mitigation for the publish path is Trusted Publishing plus short-lived credentials,
not 2FA.

The rollout: hardware-key giveaway to top maintainers (4,000 keys, July 2022); "critical"
projects, the top 1% by downloads, in May 2023; an email campaign to 474,000 non-2FA
accounts in August 2023; full enforcement January 2024.

**Threat model.** 2FA raises the bar on the browser path from "steal a password" to "steal a
password and possess a second factor", which removes password-only takeover of the account
itself. It does not follow that takeover-based publishing is solved: both 2026 takeovers on this
page post-date full enforcement, because the attacker reached a token rather than a login form.

**Not queryable.** 2FA status is absent from the public API. A project with multiple owners
from different organizations is a weak governance proxy, nothing more.

Note the gap this leaves: **domain resurrection** bypasses 2FA entirely by going through
password reset to a re-registered email domain. See
[account takeover](name-attacks.md#account-takeover-and-release-hijacking).

## OpenSSF Scorecard

Automated security-health metrics across 20+ heuristic checks: branch protection, code review,
dependency security, fuzzing, SAST usage, pinned dependencies, signed releases, token
permissions, vulnerability disclosure. Each scores 0–10, aggregated to one 0–10 figure.

**Query:** `https://api.securityscorecards.dev/projects/github.com/<owner>/<repo>`, web viewer
at [scorecard.dev](https://scorecard.dev/), or precomputed data for the top 5,000 Python
packages through the deps.dev public dataset (weekly refresh, BigQuery or snapshot download).

**Interpretation (read this before using it).** Scorecard does not detect malware. It measures
development practices. A hobby project scoring 2–3 is not malicious; a project scoring 8–9 is
not guaranteed clean, and a targeted attack can compromise a high-scoring project. Use it to
*contextualize* risk, not to decide.

**Structural limitation:** Scorecard evaluates the source repository and build pipeline, not
the published artifact. If the package on PyPI has drifted from the repo (exactly the
account-takeover scenario), Scorecard cannot see it.

## OpenSSF Package Analysis

The continuously running dynamic sandbox. Full mechanics on [Scanners](scanners.md#openssf-package-analysis).
As a *signal source*, what matters is the public BigQuery dataset:

* Project `ossf-malware-analysis`
* `packages.all_packages`, metadata
* `results.execution_result`, behavioral findings

Findings look like: file access (reads `/etc/passwd`, writes to home, deletes system files),
network (C2 connections, environment-variable exfiltration), commands executed (unpacks and
runs a secondary payload, spawns a shell), and cryptographic operations suggesting ransomware
or credential theft.

Not wired into `pip` or PyPI warnings, you query it yourself. And treat it as a risk score:
installers do legitimately write to home directories.

## OpenSSF malicious-packages

The known-malware feed. Covered in full on [Feeds](feeds.md#openssf-malicious-packages).
Presence means known-malicious; absence means undiscovered, not clean.

## Sigstore and SLSA

**Sigstore** provides keyless signing, ECDSA identity-bound certificates with transparency
logging, no long-lived private key to protect.

* CPython releases are Sigstore-signed from 3.11.0, 3.10.7, and 3.9.14 onward. **From Python
  3.14, Sigstore is the only signing method.**
* The [`sigstore`](https://pypi.org/project/sigstore/) package provides a Python client;
  `cosign` is the CLI.
* `pip` integration is in progress, not default.

**SLSA** grades build-process rigor. Level 2 is reachable in an afternoon on GitHub with
default Actions plus `cosign` and `slsa-github-generator`: source control, automated build,
signed provenance. The provenance is an in-toto document binding the artifact to a source
commit, build environment, and build command.

Two different tools, for two different things. `cosign` verifies a *signature*, so keyless
verification needs the signing certificate as well: pass `--bundle` (cert plus signature
together, the usual form now) or `--certificate` alongside `--signature`. With `--signature`
alone there is no certificate for the identity flags to check against and the command errors out.

```bash
cosign verify-blob \
  --bundle <package-file>.sigstore.json \
  --certificate-identity "https://github.com/<owner>/<repo>/.github/workflows/release.yml@refs/tags/v1.0.0" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  <package-file>
```

SLSA provenance from `slsa-github-generator` is an in-toto attestation, not a blob signature, and
`slsa-verifier` is what checks it:

```bash
slsa-verifier verify-artifact <package-file> \
  --provenance-path <provenance-file> \
  --source-uri github.com/<owner>/<repo>
```

**Status (July 2026).** Sigstore tooling is mature and the GitHub Actions integration is
straightforward, but PyPI-side adoption of SLSA provenance is low. Treat it as a future signal
rather than something you can require today.

## Governance: PEP 541 and the TUF PEPs

**[PEP 541](https://peps.python.org/pep-0541/), name retention.** Lets users request transfer
of an abandoned or squatted project name. Moderators approve when the project is empty,
abandoned, or an obvious typosquat. PyPI also blocks obvious typo variations at project
creation via fuzzy matching, and maintainers can defensively register decoy placeholder
packages for names near their own.

Separately, and not a PEP 541 action: during the **March 2024 mass typosquat campaign**
(reported counts range from ~365 to 500+ malicious registrations inside a day), PyPI
administrators halted **new project creation and new user registration for about 10 hours**,
02:16 to 12:56 UTC on 2024-03-28, while automated defenses were tightened. That was an
operational lever pulled by admins. PEP 541 governs name transfer and removal requests case by
case and confers no power to suspend registration.

Current challenge: LLM-generated typosquats include plausible README text, which defeats the
low-effort-content heuristics. Manual reports and dynamic analysis are doing the work there.

**[PEP 458](https://peps.python.org/pep-0458/) / [PEP 480](https://peps.python.org/pep-0480/) —
TUF.** PEP 458 would have PyPI sign all repository metadata with The Update Framework, so you
could verify you're talking to the real PyPI rather than a hostile mirror or MITM. PEP 480
extends that to end-to-end developer signing, so a compromise of PyPI's online keys wouldn't
break package authenticity.

**PEP 458's status is Accepted, not open**: it was approved and then deferred in early 2019 until
funding could be secured to implement it, and the implementation never came. PEP 480 is still
Draft. Neither has a ship date or a place on the 2026 roadmap. The distinction matters if you are
deciding whether to plan around TUF: the design is ratified, only unbuilt. What's actually
protecting you today is HTTPS plus PEP 740 attestations at the artifact level.

## Signal checklist

**Per-package query chain**

1. **Existence**: PyPI JSON API. A 404 means removed or never existed; a quarantined project
   returns metadata but fails to install.
2. **Known malware**: OSV API against the OpenSSF feed, all versions.
3. **Yank status**: the `yanked` and `yanked_reason` fields.
4. **Upload timing and maintainer shifts**: `upload_time`, plus `ownership.roles` compared
   against **your own earlier snapshot**. PyPI reports current ownership only, so a retrospective
   per-release maintainer diff is not possible unless you poll and store the history yourself.
5. **Governance health**: Scorecard via deps.dev or securityscorecards.dev.
6. **Observed behavior**: the Package Analysis BigQuery tables.
7. **Attestations**: the per-file `provenance` URL from the Simple API JSON; verify if present.
8. **Provenance**: SLSA build provenance, where it exists.

**Red flags (warrant review, none definitive)**

* Appears in the OpenSSF malicious dataset
* Recently yanked with a security-related reason
* Newly added maintainer with no prior history
* Package Analysis shows home-directory access or network beaconing
* Dependencies include obfuscation, crypto, or system-level libraries with no explanation
* Scorecard below 3 (weak governance, not disqualifying)
* Multiple rapid re-releases, panic response or active compromise
* README deleted or replaced with a stub

**Green signals (positive, none conclusive)**

* Valid PEP 740 attestations tied to a Trusted Publisher
* SLSA Level 2+ provenance
* Scorecard above 6
* Several independent maintainers from identifiable organizations
* Consistent release history with public code review
* No suspicious behaviors in Package Analysis data

**No public signal exists at all for:** real-time removal alerts (poll or nothing), trusted-
reporter credibility scores (internal to PyPI), and account-compromise detection.

## Sources

* [PyPI incident report: LiteLLM/Telnyx supply chain attack](https://blog.pypi.org/posts/2026-04-02-incident-report-litellm-telnyx-supply-chain-attack/), official, with the timelines
* [Project Quarantine: PyPI's new line of defense against malware](https://securityonline.info/project-quarantine-pypis-new-line-of-defense-against-malware/)
* [PyPI slashes malware response time](https://socket.dev/blog/pypi-slashes-malware-response-time), Socket
* [PEP 740: index support for digital attestations](https://peps.python.org/pep-0740/)
* [PyPI now supports digital attestations](https://blog.pypi.org/posts/2024-11-14-pypi-now-supports-digital-attestations/) · [publish attestations v1 docs](https://docs.pypi.org/attestations/publish/v1/)
* [Attestations: a new generation of signatures on PyPI](https://blog.trailofbits.com/2024/11/14/attestations-a-new-generation-of-signatures-on-pypi/), Trail of Bits · [Are we PEP 740 yet?](https://trailofbits.github.io/are-we-pep740-yet/)
* [Why use Trusted Publishing for PyPI](https://pydevtools.com/handbook/explanation/why-use-trusted-publishing-for-pypi/) · [Trusted publishers for all package repositories](https://repos.openssf.org/trusted-publishers-for-all-package-repositories.html)
* [PyPI: 2FA enforced](https://blog.pypi.org/posts/2024-01-01-2fa-enforced/) · [2FA mandate coverage](https://www.bleepingcomputer.com/news/security/pypi-mandates-2fa-for-critical-projects-developer-pushes-back/)
* [OpenSSF Scorecard](https://scorecard.dev/) · [OpenSSF Package Analysis](https://github.com/ossf/package-analysis)
* [Sigstore docs](https://docs.sigstore.dev/cosign/system_config/integration/) · [sigstore-python](https://github.com/sigstore/sigstore-python)
* [PEP 541](https://peps.python.org/pep-0541/) · [PEP 458](https://peps.python.org/pep-0458/) · [PEP 480](https://peps.python.org/pep-0480/)
* [OpenSSF Securing Software Repositories WG](https://repos.openssf.org/) · [Principles for package repository security](https://repos.openssf.org/principles-for-package-repository-security.html)
* [Defense in depth: Python supply chain security](https://bernat.tech/posts/securing-python-supply-chain/), Bernát Gábor
* [CISA: efforts to help secure the open source ecosystem](https://www.cisa.gov/news-events/news/cisa-announces-new-efforts-help-secure-open-source-ecosystem)
