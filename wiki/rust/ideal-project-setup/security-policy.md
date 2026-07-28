# Security Policy

Every public Rust project needs a security policy. It tells researchers how
to report vulnerabilities, sets expectations for response times, and
establishes a coordinated disclosure process.

## The `SECURITY.md` file

Place `SECURITY.md` in the repository root. GitHub detects it automatically
and shows a "Security" tab with a link to it.

### Reporting a vulnerability

```markdown
# Security Policy

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Report privately through either channel:

- [GitHub's private vulnerability reporting](https://github.com/you/my-crate/security/advisories/new)
  — preferred, since it keeps the report, the fix, and the advisory together.
- Email **security@example.com** with `my-crate security` in the subject.

A useful report includes the version or commit affected, the platform, what
an attacker gains, and the smallest input or configuration that demonstrates
it.
```

### Response expectations

```markdown
## What to expect

| Stage | Target |
| ----- | ------ |
| Acknowledgement of your report | within 3 business days |
| Initial assessment and severity | within 7 business days |
| Fix released, or a plan with dates | within 30 days |
```

Be honest about response times. A one-person project cannot promise 24-hour
turnaround, but it can promise a clear timeline and a follow-up if the first
message goes astray.

### Supported versions

```markdown
## Supported versions

| Version | Supported |
| ------- | --------- |
| Latest release | ✅ |
| Older releases | ❌ — upgrade to the latest |
```

Most small projects only support the latest release. Document this explicitly
so reporters know what to expect.

### Disclosure process

```markdown
## Disclosure

We follow coordinated disclosure. Once a fix is available we publish a
[GitHub Security Advisory](https://github.com/you/my-crate/security/advisories).
For anything affecting a published crate we then submit an advisory to
[RustSec](https://github.com/rustsec/advisory-db), linking the GitHub advisory
as its source. That is the database
[`cargo audit`](https://github.com/rustsec/rustsec) reads, and RustSec entries
are in turn imported into the GitHub Advisory Database — so the RustSec
submission is what actually reaches Rust users, not the other way round.

We credit reporters by name only with explicit permission. Say nothing and the
advisory stays anonymous. Please give us a chance to ship the fix before
disclosing publicly.
```

### Scope notes

```markdown
## Scope notes

Findings that are in scope include anything that escapes the intended
boundaries of the software — reading files outside the expected paths,
executing arbitrary code, corrupting configuration files, or turning hostile
input into something worse than a wrong-looking output.

Advisories in third-party crates are tracked separately by
[`cargo audit`](https://github.com/rustsec/rustsec) and
[`cargo deny`](https://github.com/EmbarkStudios/cargo-deny) in CI. If you spot
one we have missed, an ordinary issue is fine — those are already public.
```

## GitHub private vulnerability reporting

GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories)
feature lets researchers report vulnerabilities directly through the GitHub
UI. Enable it in your repository's settings:

1. Go to **Settings → Security & analysis → Private vulnerability reporting**.
2. Click **Enable**.

This is the preferred reporting channel because it keeps the report, the fix
discussion, and the advisory in one place.

## RustSec integration

When a vulnerability affects a published crate, submit an advisory to the
[RustSec Advisory Database](https://github.com/rustsec/advisory-db). This is
what `cargo audit` reads, and it is how the vulnerability reaches the broader
Rust ecosystem.

The RustSec submission should:

1. Link to the GitHub Security Advisory as the source.
2. Include the affected versions and the patched version.
3. Describe the vulnerability and its impact.

## Further reading

- [GitHub Security Advisories documentation](https://docs.github.com/en/code-security/security-advisories)
- [RustSec Advisory Database](https://github.com/rustsec/advisory-db)
- [Coordinated Disclosure (Wikipedia)](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure)
