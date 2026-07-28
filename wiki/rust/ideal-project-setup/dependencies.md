# Dependency Management

Dependencies are the largest source of risk in any Rust project. Managing them
proactively — rather than reactively — keeps the tree small, auditable, and
maintainable.

## Dependabot

[Dependabot](https://docs.github.com/en/code-security/dependabot) automates
dependency updates by opening pull requests when new versions are available.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "cargo"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Why weekly instead of daily?

- **Batching** — weekly updates produce one PR per week instead of one per
  dependency per day. Fewer PRs means less noise and more attention per PR.
- **CI cost** — every Dependabot PR triggers a full CI run. Weekly cadence
  keeps the CI bill reasonable.
- **Review bandwidth** — a human should review every dependency update.
  Weekly batches are reviewable in one sitting.

### What Dependabot covers

- **Cargo dependencies** — `Cargo.toml` and `Cargo.lock` updates.
- **GitHub Actions** — action version updates (including SHA-pinned actions).

## Version pinning strategies

### Runtime dependencies: unbounded ranges

```toml
serde = { version = "1", features = ["derive"] }
serde_json = { version = "1", features = ["preserve_order"] }
flate2 = { version = "1", default-features = false, features = ["rust_backend"] }
```

Unbounded ranges (`"1"`, `"0.3"`) let `cargo update` apply patch and minor
releases automatically. This is the right choice for well-maintained crates
with stable APIs.

### MSRV-sensitive dependencies: pinned upper bound

```toml
toml = { version = ">=1.1, <1.2", default-features = false, features = ["std", "parse", "serde"] }
```

When a dependency's MSRV is close to your own, pin the upper bound. This
prevents `cargo update` from silently raising your effective MSRV.

### Dev-dependencies: unbounded ranges

```toml
[dev-dependencies]
tempfile = "3"
filetime = "0.2"
```

Dev-dependencies never ship to end users, so the risk of an unexpected update
is lower. Unbounded ranges are fine.

## Dependency hygiene

### Keep the tree small

Every dependency is a vector for:

- **Vulnerabilities** — more crates means more CVEs to track.
- **Supply-chain attacks** — more crates means more maintainers to trust.
- **Build time** — more crates means longer `cargo build`.
- **`unsafe` code** — more crates means more `unsafe` blocks in the tree.

A rule of thumb: **if you can implement it in 50 lines of Rust without pulling
in a crate, do it yourself.** The cost of auditing and maintaining a
dependency often exceeds the cost of writing the code.

### Disable default features

```toml
flate2 = { version = "1", default-features = false, features = ["rust_backend"] }
```

Default features often pull in unnecessary dependencies. Disable them and
opt in to only what you need.

### Prefer pure-Rust backends

```toml
flate2 = { version = "1", default-features = false, features = ["rust_backend"] }
```

The `rust_backend` feature uses `miniz_oxide` (pure Rust) instead of
`libz-sys` (C library binding). This:

- Eliminates the need for a C toolchain in the build.
- Reduces the `unsafe` count in the dependency tree.
- Simplifies cross-compilation.

### Review every addition

A new dependency should be justified in the commit message or PR description:

```
feat: add TOML config file support

Adds `toml` (>=1.1, <1.2) for parsing the config file. Pinned below 1.2
because toml 1.2 raises MSRV above our 1.85.1 floor.
```

## Lockfile management

### Commit `Cargo.lock`

For **application crates** (binaries), always commit `Cargo.lock`. This
ensures reproducible builds across environments.

For **library crates**, the convention is more nuanced. If the library is
published on crates.io, `Cargo.lock` is not published (it is in `.gitignore`
by default). If the library is a workspace member of an application, commit
the workspace-level `Cargo.lock`.

### `cargo update` discipline

- Run `cargo update` deliberately, not automatically.
- Review the diff before committing — know what changed and why.
- Run the full CI suite after updating to catch regressions.

## Further reading

- [Dependabot documentation](https://docs.github.com/en/code-security/dependabot)
- [The Cargo Book: Specifying Dependencies](https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html)
- [Rust API Guidelines: Dependency hygiene](https://rust-lang.github.io/api-guidelines/necessities.html#crate-metadata)
