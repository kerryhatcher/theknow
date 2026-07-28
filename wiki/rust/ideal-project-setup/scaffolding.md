# Project Scaffolding

A Rust project's `Cargo.toml` is its identity document. Getting the metadata,
lints, and constraints right on day one avoids a cascade of fixes later.

## The `Cargo.toml` skeleton

```toml
[package]
name = "my-crate"
version = "0.1.0"
edition = "2021"
rust-version = "1.85.1"
description = "A short, clear description of what this crate does"
license = "MIT OR Apache-2.0"
repository = "https://github.com/you/my-crate"
readme = "README.md"
keywords = ["cli", "tool", "productivity"]
categories = ["command-line-utilities"]
exclude = ["docs/", "assets/"]
```

### Key fields

| Field | Purpose |
|-------|---------|
| `edition` | Always `"2021"` (or `"2024"` once stable). The edition determines which language features are available. |
| `rust-version` | The **minimum supported Rust version** (MSRV). Declare it explicitly so `cargo` and CI can enforce it. |
| `license` | Use `"MIT OR Apache-2.0"` — the standard dual-license in the Rust ecosystem. See [licensing](#licensing). |
| `repository` | Link to the source. Required for `cargo publish`. |
| `keywords` / `categories` | Help people discover the crate on crates.io. Keep them accurate. |
| `exclude` | Files to omit from the published crate. Keeps the tarball small. |

## Lints

Enable clippy's full lint suite in `Cargo.toml`:

```toml
[lints.clippy]
all = "warn"
pedantic = "warn"
nursery = "warn"
```

Then in CI, run clippy with `-D warnings` so any new lint fails the build:

```bash
cargo clippy --all-targets -- -D warnings
```

When a lint is genuinely wrong for a specific piece of code, suppress it with
an `#[allow(...)]` attribute **and a comment explaining why**:

```rust
// Safe: clamp(0.0, 100.0) guarantees the value fits in u8 with no
// truncation or sign loss.
#[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
{
    used.clamp(0.0, 100.0) as u8
}
```

## Forbidding unsafe code

If your crate does not need `unsafe`, forbid it at the crate root:

```rust
#![forbid(unsafe_code)]
```

This is a compile-time guarantee that no `unsafe` block, even in a macro
expansion, can sneak in. It also makes `cargo-geiger` findings trivially
actionable: any `unsafe` in the dependency tree is someone else's problem
to track.

## Dependency declarations

Pin versions thoughtfully:

```toml
# Unbounded range — accepts any semver-compatible update.
serde = { version = "1", features = ["derive"] }

# Pinned below a version that bumps MSRV. An unbounded range lets
# `cargo update` break `just msrv` with no code change to attribute it to.
toml = { version = ">=1.1, <1.2", default-features = false, features = ["std", "parse", "serde"] }

# Opt out of C dependencies when possible. rust_backend routes through
# pure-Rust miniz_oxide instead of libz-sys, keeping a C toolchain out
# of the build and cargo-geiger's unsafe count down.
flate2 = { version = "1", default-features = false, features = ["rust_backend"] }
```

### Rules of thumb

1. **Prefer unbounded ranges** (`"1"`, `"0.3"`) for well-maintained crates.
   They let `cargo update` apply patch releases automatically.
2. **Pin the upper bound** when a dependency's next major version would raise
   your MSRV, change a critical behaviour, or pull in a C toolchain.
3. **Disable default features** when you only need a subset. Every feature is
   a dependency that needs auditing.
4. **Prefer pure-Rust backends** over C libraries. They eliminate build-time
   toolchain requirements and reduce the `unsafe` surface.

## Licensing

The Rust ecosystem standard is **dual-licensed under MIT OR Apache-2.0**.
This means:

- Users can choose which license to follow.
- Apache-2.0's patent grant protects contributors and users.
- MIT is compatible with GPL projects.

Include both `LICENSE-MIT` and `LICENSE-APACHE` files in the repository root.
Add a note in `CONTRIBUTING.md` that contributions are dual-licensed under
the same terms.

## Dev-dependencies

Keep dev-dependencies separate and minimal:

```toml
[dev-dependencies]
tempfile = "3"    # temporary directories for integration tests
filetime = "0.2"  # file timestamp manipulation in tests
```

Dev-dependencies are not audited for supply-chain trust at the same level
as runtime dependencies — they never ship to end users — but they still
appear in `cargo-deny` and `cargo-audit` scans.

## Binary targets

```toml
[[bin]]
name = "my-crate"
path = "src/main.rs"
```

If your crate is both a library and a binary, declare a `[lib]` section too.
If it is binary-only, the `[[bin]]` section is sufficient.

## Further reading

- [The Cargo Book: Manifest format](https://doc.rust-lang.org/cargo/reference/manifest.html)
- [Rust API Guidelines: Crate metadata](https://rust-lang.github.io/api-guidelines/necessities.html#crate-metadata)
- [Rust Edition Guide](https://doc.rust-lang.org/edition-guide/)
