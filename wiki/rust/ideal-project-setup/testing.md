# Testing Strategy

A Rust project needs tests at every level. The goal is not a specific coverage
percentage but a **safety net that catches regressions before they ship**.

## Unit tests

Unit tests live in a `mod tests` block **beside the code they test**:

```rust
// src/payload.rs

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn model_name_defaults_to_claude_when_missing() {
        let payload: Payload = serde_json::from_str("{}").unwrap();
        assert_eq!(payload.model_name(), "Claude");
    }

    #[test]
    fn model_name_uses_display_name_when_present() {
        let payload: Payload =
            serde_json::from_str(r#"{"model":{"display_name":"Sonnet"}}"#).unwrap();
        assert_eq!(payload.model_name(), "Sonnet");
    }
}
```

### Rules for unit tests

1. **Test the public API**, not internals. If you need to test a private
   function, consider whether it should be public or extracted into its own
   module.
2. **One assertion per test** where practical. A test named
   `model_name_defaults_to_claude_when_missing` should test exactly that.
3. **Test edge cases** — empty strings, zero values, wrong types, missing
   fields. Every `unwrap_or_else` or `filter` is a behaviour that needs a
   test.
4. **Test the fallback chain** — when field A is missing, when field A is
   present but wrong-typed, when both A and B are present.
5. **Use `#[allow(clippy::float_cmp)]`** on the module when testing against
   exact float literals, with a comment explaining why the comparison is
   correct.

## Integration tests

Integration tests live in `tests/` and test the crate as a compiled binary:

```rust
// tests/cli.rs

use std::io::Write;
use std::process::{Command, Stdio};

#[test]
fn minimal_payload_shows_model_and_dirname_only() {
    let mut cmd = Command::new(env!("CARGO_BIN_EXE_ferrisbar"));
    cmd.stdin(Stdio::piped()).stdout(Stdio::piped());

    let mut child = cmd.spawn().expect("failed to spawn");
    child
        .stdin
        .take()
        .expect("child stdin handle")
        .write_all(b"{\"model\":{\"display_name\":\"Sonnet\"}}")
        .expect("failed to write to child stdin");

    let output = child.wait_with_output().expect("failed to wait on child");
    assert!(output.status.success());
    assert_eq!(
        String::from_utf8_lossy(&output.stdout),
        "\x1b[2mSonnet\x1b[0m"
    );
}
```

### Key patterns

- **Use `env!("CARGO_BIN_EXE_...")`** to get the path to the compiled binary.
  This is set by Cargo during `cargo test` and is the only reliable way to
  reference your own binary from integration tests.
- **Isolate from the environment** — remove env vars that could affect the
  binary's behaviour (`HOME`, `APPDATA`, `CLAUDE_CONFIG_DIR`, etc.).
- **Use `tempfile::tempdir()`** for filesystem tests. The `TempDir` is
  automatically cleaned up when it drops.
- **Test the real binary**, not internal functions. Integration tests should
  exercise the same entry point a user would.

### What integration tests cover

- **Happy path** — the most common invocation produces the expected output.
- **Error handling** — invalid input produces a graceful error, not a panic.
- **Edge cases** — empty input, large input, missing environment variables.
- **Filesystem interactions** — config file creation, log file rotation.
- **Concurrency** — multiple processes writing to the same log directory.

## Property-based testing

For functions with complex logic, consider property-based testing with
[`proptest`](https://docs.rs/proptest) or
[`quickcheck`](https://docs.rs/quickcheck):

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn compute_used_never_exceeds_100(remaining: f64, total: f64, acw: f64) {
        let used = compute_used(remaining, total, acw);
        assert!(used <= 100);
    }
}
```

## Testing philosophy

### A bug fix ships with the test that would have caught it

If a bug is reported, the first thing you write is a failing test that
reproduces it. Then you fix the code. Then the test passes. This ensures:

- The bug is actually fixed (the test proves it).
- The bug never comes back (the test stays in the suite).
- The review is obvious (the diff shows the test and the fix together).

### Never panic on input

A library or CLI tool that panics on unexpected input is a liability. Test
that every error path degrades gracefully:

```rust
#[test]
fn invalid_json_produces_empty_output() {
    let out = run_with_env("not json", &[]);
    assert_eq!(out, "");
}
```

### Test the fallback chain

When a value can come from multiple sources (config file, env var, hardcoded
default), test every priority:

```rust
#[test]
fn env_var_beats_the_config_file() {
    // Set both the config file and the env var.
    // Assert the env var wins.
}
```

## Further reading

- [The Rust Book: Writing Automated Tests](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [Rust by Example: Testing](https://doc.rust-lang.org/rust-by-example/testing.html)
- [proptest documentation](https://docs.rs/proptest)
