# Project Governance

Governance documents set expectations for how the project is run, how
contributors are expected to behave, and what rights users and contributors
have.

## Code of Conduct

A `CODE_OF_CONDUCT.md` establishes the behavioural norms for the project
community. The [Contributor Covenant](https://www.contributor-covenant.org)
is the most widely adopted template in open source.

### What it covers

- **Our pledge** — a commitment to a harassment-free experience for everyone.
- **Our standards** — examples of acceptable and unacceptable behaviour.
- **Enforcement responsibilities** — who enforces the code of conduct and how.
- **Scope** — where the code of conduct applies (project spaces, public spaces
  when representing the project).
- **Enforcement** — the process for reporting incidents and the consequences
  of violations.

### Key points

- Use the standard Contributor Covenant template. Customizing it introduces
  ambiguity.
- Include a contact method for reporting violations (email or private channel).
- Apply it equally to maintainers and contributors.

## License

The Rust ecosystem standard is **dual-licensed under MIT OR Apache-2.0**.

### Why dual-license

- **MIT** — permissive, compatible with GPL projects, simple.
- **Apache-2.0** — includes a patent grant that protects contributors and
  users.

Users can choose which license to follow. This is the
[standard arrangement](https://rust-lang.github.io/api-guidelines/necessities.html)
recommended by the Rust API Guidelines.

### Files to include

```
LICENSE-MIT      # The MIT license text
LICENSE-APACHE   # The Apache 2.0 license text
```

### Contribution licensing

In `CONTRIBUTING.md`, state that contributions are licensed under the same
terms:

> Unless you state otherwise, any contribution you intentionally submit for
> inclusion in this work shall be dual-licensed as above, with no additional
> terms.

## The `CONTRIBUTING.md` file

A good `CONTRIBUTING.md` is the first thing a new contributor reads. It
should answer every question they might have.

### Structure

1. **Welcome** — thank the contributor for their time.
2. **Code of Conduct** — link to `CODE_OF_CONDUCT.md`.
3. **Security** — link to `SECURITY.md` for private reporting.
4. **Finding something to work on** — link to issues, especially `good first
   issue` labels.
5. **Development setup** — how to clone, build, and test.
6. **The check suite** — a table of every `just` recipe and what it protects.
7. **Code standards** — testing expectations, clippy discipline, dependency
   rules, panic policy.
8. **Pull request process** — branch strategy, commit message format, CI
   requirements.
9. **Releases** — how releases work (automated, not manual).

### Example code standards section

```markdown
## Code standards

- **Tests come with the change.** Unit tests live in a `mod tests` block
  beside the code; end-to-end tests that drive the real binary live in
  `tests/cli.rs`. A bug fix should come with the test that would have caught
  it.
- **Clippy is not advisory.** `pedantic` and `nursery` are on. If a lint is
  genuinely wrong for a piece of code, `#[allow(...)]` it with a comment
  explaining why.
- **Keep the dependency tree tiny.** A PR adding a new dependency needs to
  argue for it, and will also need a `cargo vet` entry.
- **Never panic on input.** Invalid input must degrade gracefully, not crash.
```

### Example PR process section

```markdown
## Pull requests

1. Branch off `main`. Direct pushes to `main` are blocked by branch protection.
2. Write [Conventional Commits](https://www.conventionalcommits.org) —
   `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `refactor:`, `test:`.
   release-please derives the version bump and the changelog from these.
3. Run `just ci`, or at minimum `just fmt lint test`.
4. Open the PR. All CI checks must pass before merge.
5. Do not bump the version in `Cargo.toml` or edit `CHANGELOG.md` by hand.
   Release automation owns both files.
```

## Branch protection

On GitHub, protect the `main` branch:

1. Go to **Settings → Branches → Add branch protection rule**.
2. Set the branch name pattern to `main`.
3. Enable:
   - **Require a pull request before merging**
   - **Require status checks to pass before merging** (select all CI jobs)
   - **Require branches to be up to date**
   - **Do not allow bypassing the above settings**

This ensures every change is reviewed, tested, and up to date before it
reaches `main`.

## Further reading

- [Contributor Covenant](https://www.contributor-covenant.org)
- [GitHub: Setting up your project for healthy contributions](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions)
- [GitHub: Managing branch protection rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)
- [Rust API Guidelines: Crate metadata](https://rust-lang.github.io/api-guidelines/necessities.html)
