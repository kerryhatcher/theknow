# Enterprise Readiness Guide

Large enterprises and government users do not need a perfect project; they
need a project whose risks are visible, owned, and routinely managed. A mature
open-source Rust project provides evidence that answers four questions:

1. **Who is accountable?** Maintainers, security contacts, release approvers,
   and the support commitment are public and current.
2. **Can we trust a release?** The project can show the source revision,
   protected build, dependencies, hashes, SBOM, and provenance or signature.
3. **Can we operate it safely?** Installation, configuration, secure defaults,
   permissions, logging, upgrade paths, and supported environments are clear.
4. **What happens when it fails?** Vulnerabilities have a private reporting
   path, a triage process, fixes, advisories, and a published maintenance
   lifecycle.

Rust reduces many memory-safety risks, but it is not a security program by
itself. `unsafe`, FFI, parsing, authorization, cryptography, configuration,
CI, dependencies, and release credentials still need deliberate controls.

## Golden-pattern maturity model

| Stage | Minimum outcome | Evidence an adopter can inspect |
| --- | --- | --- |
| Foundation | A usable and legally clear project | README, LICENSE, versioning policy, `CONTRIBUTING.md`, supported platforms |
| Controlled development | Changes are reviewed and automatically checked | protected branch/ruleset, CODEOWNERS, CI status checks, locked builds |
| Secure supply chain | Dependencies and build inputs are constrained and monitored | `Cargo.lock`, `deny.toml`, RustSec results, action pins, SBOM |
| Trusted releases | Artifacts are attributable and verifiable | release notes, checksums, provenance/attestation or signature, verification instructions |
| Sustainable operations | Security and maintenance are predictable | `SECURITY.md`, support window, advisory history, changelog, deprecation and incident process |

Treat the first three stages as the starting requirement for a new public
project. Treat the last two as required before presenting the project as a
supported production dependency.

## What to publish in the repository

| Artifact | Owner | What it must answer |
| --- | --- | --- |
| `README.md` | maintainers | What does it do, who should use it, supported OS/architectures, quick start, security-relevant defaults and limits? |
| `LICENSE*` and notices | governance/legal owner | May we use, modify, redistribute, and receive patent rights? Are third-party notices handled? |
| `SECURITY.md` | security response owner | Where do we report privately, which versions are supported, and what response timeline applies? |
| `SUPPORT.md` or support section | maintainers | Which releases receive fixes, how long, where users get help, and what is explicitly out of scope? |
| `GOVERNANCE.md` | project lead | Who decides, how are maintainers added/removed, how are conflicts and emergency decisions handled? |
| `CONTRIBUTING.md` and `CODEOWNERS` | maintainers | How changes are tested, reviewed, licensed, and approved—especially for security and release files. |
| `CHANGELOG.md` and release notes | release manager | What changed, upgrade/breaking-change guidance, and security fixes. |
| `docs/security/` | security lead | Threat model, hardening guidance, cryptographic and key-management assumptions, abuse/resource limits, and deployment guidance. |

Do not publish names or individual contact details without consent. Use a
role mailbox or GitHub security advisory reporting where possible so the
process survives maintainer turnover.

## Repository and organization controls

Protect `main` (and release branches) with GitHub rulesets or equivalent:

- Require pull requests, passing required checks, resolved review comments,
  and at least one independent approval. Require CODEOWNER approval for CI,
  release, dependency-policy, security-policy, and unsafe/FFI areas.
- Dismiss stale approvals when code changes; block direct pushes, force pushes,
  deletion, and administrator bypass except for a narrowly documented
  break-glass process.
- Require signed commits where your organization can operate that reliably,
  and require a linear, attributable history.
- Give humans least-privilege roles; use teams rather than personal accounts;
  remove access promptly; protect organization ownership with recovery-ready
  accounts and MFA.
- Give every workflow an explicit minimal `permissions:` block. Use OIDC and
  short-lived cloud credentials rather than long-lived deployment secrets.
  Never run untrusted pull-request code with write tokens or release secrets.
- Pin third-party GitHub Actions by full commit SHA, verify their origin, and
  restrict which actions and reusable workflows may run.

These controls should be enforced by platform policy where available, not only
described in a markdown file.

## Release evidence packet

For every production release, publish or retain a packet linked from the
release notes:

1. Version, immutable source tag/commit, changelog, compatibility and upgrade
   notes.
2. Per-platform artifacts with SHA-256 checksums; signatures where your users
   require them.
3. A CycloneDX or SPDX SBOM produced for the actual release feature set. Do
   not describe development-only dependencies as shipped components.
4. Build provenance—at minimum the repository, commit, workflow identity, and
   artifact digest—plus instructions to verify it.
5. CI evidence: test/platform matrix, quality gates, dependency/advisory
   checks, and the disposition of any accepted risk.
6. Vulnerability and support status: current supported releases, fixed
   advisories, known limitations, and any configuration required to run safely.

An SBOM says what was included; provenance says where and how the artifact was
built. Neither alone proves that the software is safe. Together they make
verification and incident response much faster.

## Start new / retrofit existing

{% stepper %}

### Inventory and assign owners

List binaries, libraries, container images, publish locations, supported
platforms, maintainers, secrets, CI workflows, dependencies, and users who
consume releases. Name a release owner and a security-response owner.

### Close the public-trust gaps

Add accurate licensing, `SECURITY.md`, support window, contribution rules,
CODEOWNERS, changelog, and an issue/decision process. Do not promise SLAs the
project cannot meet.

### Lock down the path to main and release

Turn on rulesets, required checks, least-privilege workflow permissions, SHA
pinned actions, secret scanning, and dependency updates. Use a separate,
protected release environment for credentials.

### Make the build repeatable and observable

Commit the application lockfile; use `--locked` in CI and release builds; pin
the Rust toolchain; run the documented checks locally and in CI. Generate an
SBOM and checksums from the exact release build.

### Introduce supply-chain and security controls gradually

Begin with `cargo audit`/`cargo deny`, then establish `cargo vet` policy and
document time-bounded exemptions with owners and rationale. Add threat models,
fuzzing/property tests, provenance, and reproducibility work in priority order
from the project threat model.

### Operate and improve

Practice an advisory release, review access and dependency exceptions on a
cadence, publish deprecations early, and perform a blameless post-incident
review that changes code, controls, or documentation.

{% endstepper %}

## Procurement and compliance posture

Keep a concise response pack for security questionnaires: this page's
evidence, the current SBOM/provenance locations, supported-version policy,
security contact, and mappings from controls to customer frameworks. For US
federal use, the producer attestation expectations derive from the SSDF and
OMB software supply-chain guidance; a project should obtain legal and
compliance review before claiming eligibility or submitting an attestation.

The [OpenSSF Best Practices Badge](https://www.bestpractices.dev/) and
[OpenSSF Scorecard](https://securityscorecards.dev/) are useful transparent
signals, but are not substitutes for a customer's risk assessment or an
applicable government attestation.

## Source documents

- [NIST SP 800-218 SSDF](https://doi.org/10.6028/NIST.SP.800-218)
- [CISA Software Acquisition Guide for Government Enterprise Consumers](https://www.cisa.gov/resources-tools/resources/software-acquisition-guide-government-enterprise-consumers)
- [OpenSSF Best Practices Badge](https://openssf.org/projects/best-practices-badge/)
- [OpenSSF Scorecard](https://securityscorecards.dev/)
- [SLSA v1.0 specification](https://slsa.dev/spec/v1.0/)
- [GitHub rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [GitHub Actions secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
