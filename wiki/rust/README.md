# Rust

Production Rust project setup — tooling, CI/CD, security, testing, and release
patterns that catch problems before they ship. Every practice here is drawn
from real, shipping Rust projects and is designed to be in place from the
first commit, not bolted on later.

## Contents

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
