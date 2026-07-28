# Release Automation

Releases should be boring and verifiable. Automate the mechanical work, but
retain an explicit, accountable approval for a production release. Every tag,
GitHub release, binary artifact, and crates.io publish should be produced by
the protected release workflow—not by a developer's laptop.

## Conventional Commits

[Conventional Commits](https://www.conventionalcommits.org) is the foundation
of automated releases. Every commit message follows a structured format:

```
feat: add config file and JSONL logging
fix: degrade unexpectedly-typed JSON fields to None
docs: update README with installation instructions
chore: bump cargo-deny to 0.18.0
ci: add macOS to the test matrix
refactor: extract config parsing into its own module
test: add edge-case tests for empty payload
```

The prefix determines the version bump:

| Prefix | Bump | Example |
|--------|------|---------|
| `fix:` | Patch (0.0.x) | Bug fixes |
| `feat:` | Minor (0.x.0) | New features |
| `feat!:` or `BREAKING CHANGE:` | Major (x.0.0) | Breaking changes |

Other prefixes (`docs:`, `chore:`, `ci:`, `refactor:`, `test:`) do not
trigger a release.

## release-please

[release-please](https://github.com/googleapis/release-please) automates the
release process. It maintains a **release PR** that is updated on every merge
to `main`. When the release PR is merged, it:

1. Creates a Git tag (`v0.3.0`).
2. Creates a GitHub Release with auto-generated release notes.
3. Triggers downstream workflows (binary builds, crates.io publish).

### Configuration

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "rust",
  "include-component-in-tag": false,
  "include-v-in-tag": true,
  "packages": {
    ".": {
      "release-type": "rust",
      "package-name": "my-crate"
    }
  }
}
```

```json
{
  ".": "0.1.0"
}
```

### What release-please does

- **Derives the version** from commit messages since the last release.
- **Updates `Cargo.toml`** — bumps the `version` field.
- **Updates `CHANGELOG.md`** — appends a new changelog section.
- **Opens/updates a release PR** — a single PR that accumulates changes until
  you decide to merge it.
- **Creates the tag and release** — when the release PR is merged.

### What you must never do

- **Never hand-edit the `version` field in `Cargo.toml`.** Release automation
  owns it. If you edit it manually, the next release will conflict.
- **Never hand-edit `CHANGELOG.md`.** The changelog is auto-generated from
  commit messages. Hand-edits will be overwritten.

## The release workflow

```yaml
name: release-please

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    name: release-please
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.rp.outputs.release_created }}
      tag_name: ${{ steps.rp.outputs.tag_name }}
    steps:
      - uses: actions/create-github-app-token@v1
        id: app-token
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}
      - id: rp
        uses: googleapis/release-please-action@v4
        with:
          token: ${{ steps.app-token.outputs.token }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

### Why a GitHub App token?

The default `GITHUB_TOKEN` cannot trigger other workflows. Using a GitHub App
token ensures that when release-please creates a tag, the downstream build
and publish workflows actually run.

Use a dedicated GitHub App with only the permissions it needs. Keep its
private key in a protected release environment, restrict who may approve that
environment, and record the release approver. Prefer OIDC for cloud publishing
where the target registry supports it; never expose publish credentials to
pull-request workflows.

## Cross-platform binary builds

After the release is created, build binaries for every target platform:

```yaml
build:
  name: build (${{ matrix.target }})
  needs: release-please
  if: ${{ needs.release-please.outputs.release_created == 'true' }}
  runs-on: ${{ matrix.runner }}
  strategy:
    fail-fast: false
    matrix:
      include:
        - runner: ubuntu-22.04
          target: x86_64-unknown-linux-gnu
          archive_ext: tar.gz
        - runner: ubuntu-22.04-arm
          target: aarch64-unknown-linux-gnu
          archive_ext: tar.gz
        - runner: macos-14
          target: aarch64-apple-darwin
          archive_ext: tar.gz
        - runner: windows-latest
          target: x86_64-pc-windows-msvc
          archive_ext: zip
```

### Embedding the dependency tree with `cargo-auditable`

Use [`cargo-auditable`](https://github.com/rust-secure-code/cargo-auditable)
to embed the resolved dependency tree into the compiled binary:

```bash
cargo auditable build --release --locked --target ${{ matrix.target }}
```

This enables tools like `cargo audit` to scan the binary for known
vulnerabilities without access to the source code or `Cargo.lock`.

### Syncing the lockfile

After release-please bumps the version in `Cargo.toml`, the `Cargo.lock` file
still records the old version. Sync it before building:

```bash
cargo update --workspace
```

This updates only the workspace crate's version in the lockfile, leaving
every dependency pinned as committed.

## Publishing to crates.io

```yaml
publish-crate:
  name: cargo publish
  needs: [release-please, build]
  if: ${{ needs.release-please.outputs.release_created == 'true' }}
  runs-on: ubuntu-latest
  steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@v1
        with:
          toolchain: stable
      - uses: Swatinem/rust-cache@v2
      - name: Sync lockfile to bumped version
        run: cargo update --workspace
      - name: Publish to crates.io
        env:
          CARGO_REGISTRY_TOKEN: ${{ secrets.CARGO_REGISTRY_TOKEN }}
        run: cargo publish --locked
```

### The `CARGO_REGISTRY_TOKEN` secret

Set this in the GitHub repository's secrets settings. The token is generated
on crates.io and must have publish permission for the crate.

## Packaging release artifacts

```bash
# Unix
VERSION="${TAG_NAME#v}"
STAGE="my-crate-${VERSION}-${TARGET}"
mkdir -p "$STAGE"
cp "target/$TARGET/release/my-crate" "$STAGE/"
cp README.md LICENSE-MIT LICENSE-APACHE "$STAGE/"
tar -czf "${STAGE}.tar.gz" "$STAGE"

# Windows
$VERSION = "${env:TAG_NAME}".TrimStart("v")
$STAGE = "my-crate-$VERSION-$TARGET"
New-Item -ItemType Directory -Path $STAGE | Out-Null
Copy-Item "target/$TARGET/release/my-crate.exe" -Destination $STAGE
Copy-Item README.md,LICENSE-MIT,LICENSE-APACHE -Destination $STAGE
Compress-Archive -Path $STAGE -DestinationPath "$STAGE.zip"
```

## Checksums, SBOM, and provenance

A release is not complete when it is uploaded. Publish the evidence users
need to verify what they downloaded:

```bash
# Generate a deterministic checksum manifest for every release asset.
sha256sum my-crate-*.tar.gz my-crate-*.zip > SHA256SUMS

# Produce a CycloneDX SBOM for the release workspace/feature set.
cargo cyclonedx --format json --describe binaries
```

Generate the SBOM in the release build, upload it with the artifacts, and
state which target and Cargo features it describes. `cargo-cyclonedx` can use
Cargo metadata as well as the lockfile and can omit development dependencies,
which makes it more useful than a lockfile-only report for a shipped binary.

For GitHub-hosted releases, generate an artifact attestation after building
each binary. It cryptographically binds the artifact digest to the repository,
commit, and workflow identity. This is provenance—not a guarantee that the
artifact has no vulnerability.

```yaml
permissions:
  contents: read
  id-token: write
  attestations: write

# Pin the action to a reviewed full commit SHA in a real workflow.
- name: Attest release artifact
  uses: actions/attest-build-provenance@v2
  with:
    subject-path: dist/my-crate-*
```

Tell users how to verify the provenance and checksum, including the expected
repository owner and release workflow:

```bash
sha256sum --check SHA256SUMS
gh attestation verify ./my-crate --owner YOUR_ORGANIZATION \
  --signer-workflow YOUR_ORGANIZATION/YOUR_REPOSITORY/.github/workflows/release.yml
```

The exact GitHub attestation action/version evolves; use the current official
GitHub guidance, pin the selected action by full SHA, and test the verification
command before documenting it as a release guarantee.

## Further reading

- [Conventional Commits specification](https://www.conventionalcommits.org)
- [release-please documentation](https://github.com/googleapis/release-please)
- [cargo-auditable documentation](https://github.com/rust-secure-code/cargo-auditable)
- [crates.io publishing guide](https://doc.rust-lang.org/cargo/reference/publishing.html)
- [cargo-cyclonedx documentation](https://docs.rs/cargo-cyclonedx/)
- [GitHub artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations)
- [GitHub: verify attestations from a reusable workflow](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/increase-security-rating)
