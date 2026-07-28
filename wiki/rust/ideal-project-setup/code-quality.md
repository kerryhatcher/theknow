# Code Quality Gates

Every line of Rust code should pass through automated quality gates before
it reaches a pull request. These gates run locally via `just` and in CI.

## Formatting: `rustfmt`

```bash
# Verify (CI — does not modify files)
cargo fmt --check

# Fix (local — reformats in place)
cargo fmt
```

CI runs `cargo fmt --check` and fails if any file is unformatted. Developers
run `cargo fmt` (or configure their editor to format on save) before pushing.

## Linting: `clippy`

```bash
# Run clippy on all targets (bin, lib, tests, examples)
cargo clippy --all-targets -- -D warnings
```

The `-D warnings` flag turns every clippy warning into a hard error. Combined
with the `[lints.clippy]` configuration in `Cargo.toml`:

```toml
[lints.clippy]
all = "warn"
pedantic = "warn"
nursery = "warn"
```

This means:

- **`all`** — every stable lint that is on by default.
- **`pedantic`** — opinionated lints that catch subtle bugs and enforce
  idiomatic code. Some may need `#[allow(...)]` with a comment.
- **`nursery`** — new lints still in development. They catch emerging best
  practices before they become stable.

### Suppression discipline

When a lint is genuinely wrong for a specific piece of code, suppress it
narrowly (on the expression or function, not the module) with a comment:

```rust
// Safe: clamp(0.0, 100.0) guarantees the value fits in u8 with no
// truncation or sign loss.
#[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
{
    used.clamp(0.0, 100.0) as u8
}
```

Never suppress a lint without explaining why. If you cannot write a
convincing comment, the lint is probably right.

## The `justfile`

A `justfile` provides a single entry point for every quality gate. Developers
run `just ci` to reproduce exactly what CI runs:

```makefile
# Check formatting without modifying files.
fmt:
    cargo fmt --check

# Reformat in place.
fmt-fix:
    cargo fmt

# Lint, treating warnings as errors.
lint:
    cargo clippy --all-targets -- -D warnings

# Run the test suite.
test:
    cargo test

# Run every check. Fails fast on the first failing recipe.
ci: fmt lint test audit msrv deny trivy vet geiger
```

### Why `just` instead of `make` or shell scripts?

- **Self-documenting** — `just` lists every recipe with its comment.
- **Cross-platform** — works on Linux, macOS, and Windows.
- **No shell escaping surprises** — each recipe is a single command.
- **Fail-fast by default** — `just ci` stops at the first failure.

## What the gates protect

| Gate | Command | What it protects |
|------|---------|------------------|
| `just fmt` | `cargo fmt --check` | Consistent formatting |
| `just lint` | `cargo clippy --all-targets -- -D warnings` | Bugs, style, idiomatic code |
| `just test` | `cargo test` | Correctness |
| `just audit` | `cargo audit` | Known advisories in dependencies |
| `just msrv` | `cargo msrv verify` | MSRV drift from dependency bumps |
| `just deny` | `cargo deny check` | Licenses, banned crates, duplicates |
| `just trivy` | `trivy fs --scanners vuln,secret` | Filesystem vulns and secrets |
| `just vet` | `cargo vet check` | Supply-chain trust policy |
| `just geiger` | `cargo geiger` | Unsafe usage (informational) |

## Installing the tools

```bash
cargo install just cargo-audit cargo-msrv cargo-deny cargo-vet cargo-geiger
# trivy: https://trivy.dev/latest/getting-started/installation/
```

## Further reading

- [rustfmt documentation](https://github.com/rust-lang/rustfmt)
- [Clippy documentation](https://doc.rust-lang.org/clippy/)
- [just documentation](https://just.systems/man/en/)
