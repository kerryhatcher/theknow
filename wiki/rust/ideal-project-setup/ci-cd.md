# CI/CD Pipeline

A production Rust CI pipeline runs every quality gate on every commit, across
multiple operating systems, and fails fast on the first error.

## Design principles

1. **Separate jobs for separate concerns** — test, lint, MSRV, security, and
   vet each get their own job. A lint failure should not block the test suite
   from running.
2. **Matrix builds for cross-platform testing** — run tests on Linux, macOS,
   and Windows. Rust code that works on one platform may fail on another
   (path separators, line endings, environment variables).
3. **Fail fast within a job** — each job stops at the first failure. The
   developer gets immediate feedback on what broke.
4. **Cache aggressively** — `Swatinem/rust-cache` caches the `target/`
   directory and `~/.cargo/` between runs, cutting CI time by 50-80%.

## The CI workflow

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

env:
  CARGO_TERM_COLOR: always

# Default every job to read-only. Add narrowly scoped write permissions only
# to the release/provenance job that needs them.
permissions:
  contents: read

jobs:
  test:
    name: test (${{ matrix.os }})
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@v1
        with:
          toolchain: stable
      - uses: Swatinem/rust-cache@v2
      - uses: taiki-e/install-action@v2
        with:
          tool: just
      - run: cargo test --locked

  lint:
    name: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@v1
        with:
          toolchain: stable
          components: rustfmt, clippy
      - uses: Swatinem/rust-cache@v2
      - uses: taiki-e/install-action@v2
        with:
          tool: just
      - run: cargo fmt --check
      - run: cargo clippy --all-targets --locked -- -D warnings

  msrv:
    name: msrv (1.85.1)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@v1
        with:
          toolchain: "1.85.1"
      - uses: Swatinem/rust-cache@v2
      - uses: taiki-e/install-action@v2
        with:
          tool: just
      - run: cargo test --locked

  security:
    name: security
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@v1
        with:
          toolchain: stable
      - uses: Swatinem/rust-cache@v2
      - uses: taiki-e/install-action@v2
        with:
          tool: just,cargo-audit,cargo-deny,cargo-geiger
      - run: cargo audit
      - run: cargo deny check
      - uses: aquasecurity/trivy-action@v0.36.0
        with:
          scan-type: fs
          scanners: vuln,secret
          exit-code: "1"
          skip-dirs: target
      - run: just geiger

  vet:
    name: vet
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@v1
        with:
          toolchain: stable
      - uses: Swatinem/rust-cache@v2
      - uses: taiki-e/install-action@v2
        with:
          tool: just,cargo-vet
      - run: just vet
```

## Job breakdown

### `test` — cross-platform test suite

- Runs on **Linux, macOS, and Windows**.
- `fail-fast: false` — a failure on one OS does not cancel the others.
  Windows failures are often environment-specific and worth seeing.
- Runs `just test` (`cargo test`).

### `lint` — formatting and clippy

- Runs on Ubuntu only (formatting and clippy are platform-independent).
- Installs `rustfmt` and `clippy` components explicitly.
- Runs `just fmt` then `just lint`.

### `msrv` — MSRV enforcement

- Pins the exact toolchain from `Cargo.toml`'s `rust-version`.
- Runs the full test suite, not just `cargo check`.
- Catches dependency bumps that silently raise the effective MSRV.

### `security` — vulnerability and supply-chain scanning

- Runs `cargo audit` (RustSec advisory database).
- Runs `cargo deny check` (licenses, bans, sources).
- Runs Trivy (filesystem vulns and secrets).
- Runs `cargo geiger` (informational, never fails the build).

### `vet` — supply-chain trust

- Runs `cargo vet check` (audit policy enforcement).
- Separate from the security job because it has different tooling and
  different failure modes.

## Pinning action versions

Pin every GitHub Action to a specific commit SHA, with a comment noting the
semver tag:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v4.2.0
- uses: dtolnay/rust-toolchain@e97e2d8cc328f1b50210efc529dca0028893a2d9 # v1
- uses: Swatinem/rust-cache@c19371144df3bb44fab255c43d04cbc2ab54d1c4 # v2.9.1
- uses: taiki-e/install-action@7572810d7dd469b651bb7793945692cf78da5dd7 # v2.85.0
```

This prevents a compromised action release from injecting malicious code into
your CI pipeline. Dependabot will open PRs to update the pinned SHAs.

Also enable the repository or organization policy that requires full-length
SHA pins, restricts allowed third-party actions/reusable workflows, and make
workflow permissions explicit. A workflow triggered by an untrusted fork must
not receive secrets or a write-capable token; release/publishing workflows
must only run from protected refs and environments.

## Evidence retention and scheduled checks

PR checks prevent regressions introduced by a change, but a dependency may be
disclosed as vulnerable on an otherwise quiet project. Add scheduled runs for
RustSec/license checks and record alert triage. Retain release-job logs,
checksums, SBOMs, provenance/signatures, and test reports for the length of
the support period or contractual retention requirement. Treat CI artifacts as
potentially sensitive: redact logs and avoid uploading secrets, production
data, or full core dumps.

## Further reading

- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [dtolnay/rust-toolchain](https://github.com/dtolnay/rust-toolchain)
- [Swatinem/rust-cache](https://github.com/Swatinem/rust-cache)
- [taiki-e/install-action](https://github.com/taiki-e/install-action)
- [GitHub Actions secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [GitHub action pinning policy](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
