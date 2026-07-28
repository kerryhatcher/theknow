# MSRV Management

The **Minimum Supported Rust Version** (MSRV) is the oldest Rust toolchain
your crate is guaranteed to build with. Declaring and enforcing an MSRV
prevents dependency bumps from silently dropping users on older toolchains.

## Declaring the MSRV

Set `rust-version` in `Cargo.toml`:

```toml
[package]
rust-version = "1.85.1"
```

This field tells `cargo` (and users) the minimum toolchain version. It is
also read by `cargo-msrv` and can be checked in CI.

## Verifying the MSRV

Use [`cargo-msrv`](https://github.com/foresterre/cargo-msrv) to verify that
the crate still builds on its declared MSRV:

```bash
cargo msrv verify
```

This command:

1. Downloads the exact toolchain specified in `rust-version`.
2. Runs `cargo check` (or `cargo test` with `--verify-with`).
3. Fails if the build breaks, indicating a dependency bump has raised the
   effective MSRV above the declared one.

### In the justfile

```makefile
# Verify the crate still builds on its declared MSRV (Cargo.toml's
# rust-version), catching drift from dependency bumps.
msrv:
    cargo msrv verify
```

## Enforcing in CI

CI runs the full test suite against the pinned MSRV toolchain, not just
`cargo check`. This catches runtime behaviour differences between toolchain
versions:

```yaml
jobs:
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
      - run: just test
```

### Why run the full test suite instead of just `cargo check`?

- A feature that compiles on stable may behave differently on an older
  toolchain (e.g., const evaluation changes, trait resolution changes).
- The MSRV job is the **canary** — if it breaks, you know exactly which
  dependency bump or language feature caused it.

## Preventing MSRV drift

### Version-pin dependencies that sit near the MSRV floor

When a dependency's MSRV is close to your own, pin the upper bound:

```toml
# Pinned below 1.2: toml 1.1.3 declares rust-version 1.85, one patch under
# our 1.85.1 MSRV. An unbounded range lets `cargo update` break `just msrv`
# with no code change to attribute it to.
toml = { version = ">=1.1, <1.2" }
```

### Review dependency MSRVs before updating

Before running `cargo update`, check whether the new version of each
dependency raises its MSRV. Tools like `cargo-msrv` and
[cargo-info](https://github.com/rust-lang/cargo) can help.

## When to raise the MSRV

- A dependency you need has raised its MSRV and you cannot pin the old
  version.
- A language feature stabilized in a newer toolchain would significantly
  improve the code.
- The old toolchain is no longer supported by the Rust project (each stable
  release is supported for 6 weeks after the next stable release).

When you raise the MSRV, do it in a dedicated commit or PR so the change is
visible in the changelog and release notes.

## Further reading

- [cargo-msrv documentation](https://github.com/foresterre/cargo-msrv)
- [dtolnay/rust-toolchain action](https://github.com/dtolnay/rust-toolchain)
- [Rust platform support](https://doc.rust-lang.org/nightly/rustc/platform-support.html)
