# Supply Chain Security

Rust's dependency ecosystem is one of its greatest strengths — and one of its
largest attack surfaces. Every crate you depend on is a potential vector for
malicious code, vulnerable libraries, or license violations. Three tools work
together to manage this risk.

## `cargo-deny`: license, ban, and duplicate checking

`cargo-deny` checks your dependency tree against a policy file (`deny.toml`).
It covers four areas:

### Configuration

```toml
# deny.toml

[graph]
all-features = false
no-default-features = false

[output]
feature-depth = 1

# `cargo deny check advisories` — RustSec vulnerability/yanked-crate database.
[advisories]
ignore = []

# `cargo deny check licenses` — only these licenses are allowed.
[licenses]
allow = ["MIT", "Apache-2.0", "Unicode-3.0"]
confidence-threshold = 0.8

[licenses.private]
ignore = false

# `cargo deny check bans` — duplicate/banned/wildcard-version crates.
[bans]
multiple-versions = "warn"
wildcards = "allow"
highlight = "all"
workspace-default-features = "allow"
external-default-features = "allow"
allow-workspace = false

# `cargo deny check sources` — only allow crates.io.
[sources]
unknown-registry = "deny"
unknown-git = "deny"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]

[sources.allow-org]
github = []
gitlab = []
bitbucket = []
```

### What each section protects

| Section | Command | What it catches |
|---------|---------|-----------------|
| `[advisories]` | `cargo deny check advisories` | Known vulnerabilities and yanked crates |
| `[licenses]` | `cargo deny check licenses` | Copyleft or unapproved licenses in the tree |
| `[bans]` | `cargo deny check bans` | Duplicate versions of the same crate, banned crates |
| `[sources]` | `cargo deny check sources` | Dependencies from untrusted registries or git repos |

### Key decisions

- **License allowlist** — start with `["MIT", "Apache-2.0", "Unicode-3.0"]`
  and add licenses only after reviewing them. Every addition is a conscious
  decision.
- **Source restrictions** — deny unknown registries and unknown git sources.
  A dependency pulled from a random GitHub repo is an unvetted supply-chain
  risk.
- **Multiple versions** — warn on duplicates. Two versions of the same crate
  double the audit surface and may indicate a semver mismatch.

## `cargo-vet`: supply chain audits

`cargo-vet` (from Mozilla) establishes a **trust policy** for every
dependency. Each crate must be either:

1. **Audited** — someone with authority has reviewed the source and vouches
   for it.
2. **Exempted** — the project explicitly accepts the risk for a specific
   version.
3. **Imported** — an audit from a trusted third party (Google, Mozilla) is
   accepted.

### Configuration

```toml
# supply-chain/config.toml

[cargo-vet]
version = "0.10"

# Import audits from Google and Mozilla.
[imports.google]
url = "https://raw.githubusercontent.com/google/rust-crate-audits/main/audits.toml"

[imports.mozilla]
url = "https://raw.githubusercontent.com/mozilla/supply-chain/main/audits.toml"

[policy.my-crate]
audit-as-crates-io = false

# Exemptions for crates that have not been audited.
[[exemptions.serde]]
version = "1.0.229"
criteria = "safe-to-deploy"

[[exemptions.tempfile]]
version = "3.10.1"
criteria = "safe-to-run"
```

### Audit criteria

| Criteria | Meaning |
|----------|---------|
| `safe-to-deploy` | The crate is safe to ship to end users. No malicious or vulnerable code. |
| `safe-to-run` | The crate is safe to run during development or testing. Not necessarily safe to ship. |

### Workflow

1. **First audit** — when adding a new dependency, run `cargo vet` to see
   what needs auditing. Add exemptions for crates you have reviewed.
2. **Update audits** — when a dependency version changes, `cargo vet` checks
   whether the delta has been audited. If not, you need a new exemption or
   audit entry.
3. **Import audits** — Google and Mozilla maintain public audit sets.
   Importing them covers the most common crates (serde, quote, syn, etc.).

### Files

```
supply-chain/
├── config.toml    # Policy, imports, exemptions
├── audits.toml    # Your own audit entries (initially empty)
└── imports.lock   # Pinned import state (auto-generated)
```

## `cargo-audit`: RustSec advisory database

`cargo-audit` checks your dependency tree against the
[RustSec Advisory Database](https://rustsec.org) — a curated collection of
known vulnerabilities and yanked crates.

```bash
cargo audit
```

This is the fastest check to run and the one most likely to catch something
actionable. Run it in CI on every commit.

### What it catches

- **Known vulnerabilities** — crates with published CVEs.
- **Yanked crates** — crates that have been removed from crates.io due to
  a serious bug or security issue.
- **Outdated crates** — versions that have a known fix available.

## Putting it together

In CI, run all three checks in the security job:

```yaml
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - uses: taiki-e/install-action@v2
        with:
          tool: cargo-audit,cargo-deny
      - run: cargo audit
      - run: cargo deny check
```

And in the vet job:

```yaml
jobs:
  vet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - uses: taiki-e/install-action@v2
        with:
          tool: cargo-vet
      - run: cargo vet check
```

## Further reading

- [cargo-deny documentation](https://embarkstudios.github.io/cargo-deny/)
- [cargo-vet documentation](https://mozilla.github.io/cargo-vet/)
- [cargo-audit documentation](https://github.com/rustsec/rustsec)
- [RustSec Advisory Database](https://rustsec.org)
