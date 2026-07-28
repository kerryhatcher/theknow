# Rust

Production Rust project setup — tooling, CI/CD, security, testing, release,
and governance patterns that make the project credible to maintainers and
defensible to enterprise and government adopters. The goal is evidence, not
checkboxes: a user should be able to see how changes are controlled, how
releases are produced, what is in them, and how the project responds when
something goes wrong.

This is a practical pattern, not a claim of compliance. Map it to your
organization's legal, contractual, and regulatory obligations. In particular,
US federal consumers commonly assess suppliers against the [NIST Secure
Software Development Framework (SSDF)](https://doi.org/10.6028/NIST.SP.800-218).

## Contents

- [Enterprise readiness guide](enterprise-readiness.md) — maturity model,
  adopter evidence, ownership, and a retrofit sequence
- [Secure development lifecycle](secure-development.md) — threat modeling,
  secure defaults, review, testing, incident learning, and SSDF mapping
- [Project scaffolding](scaffolding.md) — `Cargo.toml` setup, MSRV, edition,
  lints, `#![forbid(unsafe_code)]`
- [Code quality gates](code-quality.md) — `rustfmt`, `clippy`, and how to
  configure them
- [Testing strategy](testing.md) — unit tests, integration tests, property-based
  testing, and what to test
- [Supply chain security](supply-chain.md) — `cargo-deny`, `cargo-vet`,
  `cargo-audit`, and dependency trust
- [Security scanning](security-scanning.md) — Trivy, `cargo-geiger`, and
  vulnerability detection
- [MSRV management](msrv.md) — minimum supported Rust version, verification,
  and CI enforcement
- [CI/CD pipeline](ci-cd.md) — GitHub Actions matrix builds, separate job
  design, and release automation
- [Release automation](releases.md) — `release-please`, conventional commits,
  `cargo publish`, and cross-platform binaries
- [Dependency management](dependencies.md) — Dependabot, version pinning,
  and dependency hygiene
- [Local development](local-dev.md) — `justfile`, `CLAUDE.md`,
  `CONTRIBUTING.md`, and the developer experience
- [Security policy](security-policy.md) — `SECURITY.md`, private vulnerability
  reporting, and coordinated disclosure
- [Project governance](governance.md) — `CODE_OF_CONDUCT.md`, `LICENSE`,
  `CONTRIBUTING.md`, and community standards

## The non-negotiable release baseline

Before asking a risk-conscious organization to run a release, make sure it
has a supported-version policy, private vulnerability reporting, protected
default branch, reviewed and reproducible CI inputs, a committed lockfile (for
applications), dependency/license/advisory policy, a published SBOM, release
provenance or signatures, checksums, and a documented way to verify them.
The enterprise guide explains the evidence each control should produce.

## Source documents

- [NIST SP 800-218: Secure Software Development Framework](https://doi.org/10.6028/NIST.SP.800-218)
- [OpenSSF Best Practices Badge](https://openssf.org/projects/best-practices-badge/)
- [SLSA specification](https://slsa.dev/spec/v1.0/)
- [CISA Software Acquisition Guide for Government Enterprise Consumers](https://www.cisa.gov/resources-tools/resources/software-acquisition-guide-government-enterprise-consumers)
