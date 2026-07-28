# Secure Development Lifecycle

Secure development is a repeatable set of decisions, checks, and records—not
a scanner run before release. This page adapts the NIST SSDF to a Rust project
and connects each practice to a concrete repository artifact.

## Secure-by-design principles for Rust

- **Start from a threat model.** Identify assets, trust boundaries, attacker
  capabilities, entry points, privilege transitions, dependencies, and denial
  of service risks before choosing controls. Update it when the architecture,
  deployment model, or security boundary changes.
- **Choose safe defaults.** Require explicit opt-in for network exposure,
  dangerous file writes, telemetry, weak crypto, and privileged operations.
  Fail closed for authorization and validation; make secure behavior easy to
  retain in deployment templates and examples.
- **Minimize authority and attack surface.** Keep privileges, exposed APIs,
  enabled Cargo features, dependencies, open ports, accepted file formats, and
  data retention as small as practical. Put privileged operations behind a
  narrow interface.
- **Treat all external input as hostile.** Bound lengths, recursion, work,
  allocation, retry, concurrency, paths, and decompression. Validate before
  parsing or indexing; do not `unwrap`, `expect`, or panic on untrusted input.
- **Use Rust's safety guarantees deliberately.** Prefer safe Rust and forbid
  `unsafe` when possible. For every unavoidable `unsafe` block or FFI boundary,
  document its safety invariant, validate inputs at the boundary, and add
  focused tests. Rust does not protect against logic, authorization, resource
  exhaustion, or supply-chain flaws.
- **Use reviewed cryptography.** Do not implement primitives or protocols.
  Use maintained libraries and safe APIs; define key generation, storage,
  rotation, algorithms, protocol versions, and failure behavior in the threat
  model.

## Required engineering loop

| When | Required activity | Evidence |
| --- | --- | --- |
| Design or major change | Threat model and security requirements; review data flows and trust boundaries | ADR/design document, issue, or `docs/security/threat-model.md` |
| Every change | Peer review; formatting, linting, tests, dependency lock discipline | pull request, CI checks, review record |
| Boundary-sensitive change | Negative tests, property tests/fuzzing where parsers or state machines are involved | tests, corpus, fuzz CI result |
| Dependency/tooling change | License/source/advisory review and supply-chain policy update | dependency PR rationale, `deny.toml`, `supply-chain/` change |
| Release | Verify release candidate from a clean, locked build; publish SBOM, hashes, and provenance/signature | release workflow and release assets |
| Incident or escaped defect | Triage, fix, advisory as appropriate, root-cause review, and systemic corrective action | private advisory, public advisory, post-incident action items |

## Testing security properties

Use ordinary tests for known cases, then choose the technique that fits the
risk:

- **Property testing** (`proptest`) for invariants: parsers do not panic,
  serializers round trip, limits are never exceeded, and authorization never
  grants more than requested.
- **Fuzzing** (`cargo fuzz`, built on `libFuzzer`) for parsers, decoders,
  protocol handlers, file readers, and FFI boundaries. Keep the corpus under
  version control when it is safe to publish; run fuzzing continuously or on a
  scheduled budget, because it is not a deterministic PR gate.
- **Mutation testing** as a periodic signal that tests fail for meaningful
  behavioral changes; do not equate coverage percentage with security.
- **Integration and adversarial tests** for authentication, authorization,
  filesystem traversal/symlink behavior, concurrency, upgrade/migration, and
  operational limits.

Sanitizers and Miri can add value, particularly around `unsafe`, FFI, and
concurrency. Treat them as additional diagnostics with toolchain/platform
constraints, not as proof of correctness.

## Rust-specific policy decisions

Document these decisions in the repository rather than leaving them implicit:

| Topic | Policy to record |
| --- | --- |
| `unsafe` | Allowed or forbidden; CODEOWNER/reviewer requirement; invariant comment and test expectations; periodic `cargo geiger` trend review |
| FFI / native code | Supported targets, compiler/library provenance, ABI boundary validation, patch and vulnerability ownership |
| Panics | Whether public APIs and CLI input paths may panic (normally: no); abort/unwind policy; test strategy |
| Features | Default feature set, security impact of optional features, supported combinations, and minimum/restricted build profile |
| Network and files | Timeouts, size/concurrency limits, redirect/TLS policy, path/symlink policy, permission model, and logging/redaction |
| Dependencies | Approved sources/licenses, update cadence, MSRV rule, audit/exemption policy, and end-of-life response |

## SSDF crosswalk

The SSDF groups its practices as Prepare the Organization (PO), Protect the
Software (PS), Produce Well-Secured Software (PW), and Respond to
Vulnerabilities (RV). The following is a useful project-level mapping, not a
certification claim.

| SSDF outcome | Rust project implementation |
| --- | --- |
| PO: defined secure-development requirements and roles | governance, support/security policies, maintainer/release ownership, documented threat model and tool policy |
| PS: protected development environment and components | protected branches, MFA/access review, least-privilege CI, pinned actions, locked dependencies, source/secret controls |
| PW: secure design, code, test, and release | secure defaults, review, `clippy`, tests/fuzzing, `unsafe`/FFI policy, `cargo deny`, RustSec scanning, SBOM, provenance |
| RV: identify, assess, remediate, and learn from vulnerabilities | private reporting, supported-version policy, advisory workflow, patch releases, dependency monitoring, post-incident improvement |

## Source documents

- [NIST SP 800-218 SSDF](https://doi.org/10.6028/NIST.SP.800-218)
- [CISA Secure by Design](https://www.cisa.gov/securebydesign)
- [Rust Fuzz Book](https://rust-fuzz.github.io/book/)
- [The Rustonomicon: Unsafe Rust](https://doc.rust-lang.org/nomicon/)
- [RustSec Advisory Database](https://rustsec.org/)
