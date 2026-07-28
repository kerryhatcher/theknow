---
description: Testing strategy, certification checklist, distribution paths, and safe deployment for Alexa custom skills.
---

# Testing, certification, and distribution

The path from working locally to live on other people's devices. This covers the testing ladder
(cheapest first), beta distribution, the certification gauntlet, versioning discipline, and the
analytics you get after launch. Assumes you have a [skill interaction model](interaction-model.md)
and [backend](skill-setup-and-tooling.md) already working; this is about validating it and moving
it forward.

## Testing ladder

Test cheaply first, push to hardware last.

| What | Cost | Catches | Misses |
|---|---|---|---|
| Unit tests (serde, request/response JSON) | Near-free | Request contract shape, handler logic, serialization | Real NLU matching, device latency, APL rendering |
| `ask dialog` + `ask simulate` | 1–2s per invocation | Multi-turn utterances, intent routing, speech output | APL display, touch behavior, real device quirks |
| Developer Console simulator | 1–2 clicks | Voice/text input, APL preview on multiple screen sizes, full JSON inspection | APL touch events, timing, performance under load, actual device rendering fidelity |
| APL Authoring Tool preview | Drag/drop + live | Component layout, responsiveness across viewports | On-device rendering, animations, tap zones at actual DPI, scrolling feel |
| Physical device (Echo Show) | Marginal | Pixel-perfect layout, touch hit zones, animations, actual response latency, real firmware behavior | Rare firmware/hardware bugs, full fleet behavior variance |

**Key caveat on the console simulator:** it is an approximation. The APL preview does not faithfully
reproduce on-device rendering quality, touch hit zones, animation timing, or gesture scrolling. A
skill with a display *must* be validated on real hardware before certification. Simulators catch
schema errors and obvious intent mismatches; they don't catch pixel-alignment bugs or touch-zone
dead zones that will frustrate users on an actual Show.

For a pure voice-only skill (no APL), the console simulator is sufficient for certification testing.
For any skill with a display, you need hardware.

## Beta testing

Use the **Skill Beta Testing** program to extend access to a limited set of real testers before
certification or public launch.

**How it works:** on the Distribution page, expand the Beta Test section, click **Start Test**, and
add up to 500 tester email addresses. Copy the enrollment link and send it to each tester (Amazon
no longer sends invitations on your behalf). Testers click the link, authenticate with their
Amazon account, and enable the skill via the Alexa app. The skill then appears on their devices
registered to that email address.

**Limits:** beta tests run for 90 days, then automatically end. Amazon auto-removes any tester
who doesn't enroll within 30 days. The tester's device email must match the enrollment email.
Testers are free; no cost to you or to them. The skill remains uncertified while in beta.

**When to use it:** beta testing bridges the gap between personal testing (your own account) and
public certification. It's the standard way to validate a skill with real users on their devices
without certifying it. Useful for gathering feedback on UX, testing on hardware variants you don't
own, and validating behavior before the certification gauntlet.

## Certification requirements

Certification is only needed if you want the skill to appear in the public Alexa Skills Store.
Personal and beta skills skip it entirely.

### Pre-submission checklist

Work through these categories before you hit Submit. Amazon's review focuses on these areas.

**Built-in intents:** Your skill must handle `AMAZON.HelpIntent`, `AMAZON.CancelIntent`,
`AMAZON.StopIntent`, and `AMAZON.NavigateHomeIntent`. These are the baseline required intents for
any custom skill. Test them explicitly; don't assume defaults suffice.

**No dead-end sessions:** A user must always be able to exit the skill cleanly via
`AMAZON.CancelIntent` or `AMAZON.StopIntent`. Testing: invoke the skill, say "stop" or "cancel"
from any conversation state. The skill must release the session and return control to Alexa.

**Invocation name:** Lowercase, single or two-word phrase, no ordinal words ("first," "second"),
no articles at the start. Examples: "home stats," "my dashboard." Avoid anything that might
conflict with built-in skill names or Amazon's own brands.

**No screenless dead ends:** If your skill has a display interface (APL), it must also work on
voice-only devices (Echo, Echo Dot). Check `context.System.device.supportedInterfaces` for
`Alexa.Presentation.APL`. If absent, respond with voice/card output only, never throw an error.

**Privacy policy and terms URLs:** Both are mandatory. They must be publicly accessible, return
HTTP 200 (not behind login/paywalls), and clearly describe what your skill does with user data.
Amazon's review will load and read them. Host them on your own domain or a CDN you control, not on
a third-party wiki or blog that might disappear.

**Permissions manifest:** Any permission your skill requests (device address, customer profile,
notifications) must match what the skill actually uses. Requesting a permission you don't use is a
red flag. Requesting a permission without proper user consent flow is an automatic fail.

**Child-directed content:** Mark this correctly in the skill metadata. If your skill targets
children under 13, you must comply with COPPA: no third-party ads or tracking, no "personalized"
behavior without verifiable parental consent. Amazon will audit this claim.

**Account linking:** If your skill uses account linking (OAuth2), the authorization server must
respond within 4.5 seconds and return the access token in under 360 seconds (6 minutes). Stale or
missing tokens cause user friction and certification failure.

Full requirements: [Certification Requirements for Custom Skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/certification-requirements-for-custom-skills.html).

## Distribution options

| Path | Certification | Account | Access | Use case |
|---|---|---|---|---|
| Development (your account only) | No | Your Amazon dev account | Your own Echo devices | Personal project, prototype |
| Beta testing | No | Your Amazon dev account | Up to 500 invited testers | Family/friends, pre-launch feedback |
| Alexa Smart Properties / private | Depends | Enterprise/org account | Org members | Internal corporate skill, on-campus use |
| Public Store | Yes | Your Amazon dev account | Any Alexa user, global discovery | Public release, monetization |

**Development stage** is the default. A skill in development is automatically enabled on every
Alexa device signed into the same Amazon account that created it. No publishing, no review, no
beta invite needed. If you want a personal dashboard on your own Show, this is all you need.

**Alexa for Business** (account linking for multi-user enterprise scenarios) is largely legacy. As
of March 2023, the Alexa Business Skill API was deprecated. For organization-wide skills today,
use [Alexa Smart Properties](https://developer.amazon.com/en-US/alexa/alexasmartproperties) if you
have an enterprise contract, or beta testing for smaller groups.

**Public Store** requires certification (5+ business days) and gives you global discoverability.
Amazon reviews the skill against the checklist above and can iterate with questions. Once
certified, a new development version is automatically created so you can continue iterating
without affecting the live skill.

## Account linking and permissions

When your skill needs a real user identity (to look up their data from an external system, for
example), you declare this via **account linking** in the skill metadata.

**OAuth2 flow:** Alexa acts as the OAuth2 client. When a user enables your skill, the Alexa app
directs them to your authorization server (your own login page or a third-party service like Auth0).
After they authenticate and consent, your server returns an access token to Amazon, which stores it.
On each skill invocation, the request includes the access token in `context.System.user.permissions.consentToken`.

Amazon recommends the **authorization code grant** (with refresh token) over implicit grant because
it allows Alexa to renew the token without user re-authentication. Support for PKCE (Proof Key for
Code Exchange) is available for added security. Your authorization server must respond within 4.5
seconds and use HTTPS with a certificate from an Amazon-approved CA.

**Permission model (without account linking):** Skills can request permission to access specific
customer data: device address (full address or postal code only), customer contact information
(name, email, phone), or device settings (timezone, temperature units). Users grant or revoke these
permissions in the Alexa app. Your skill can subscribe to permission-changed events to detect when
consent is granted or revoked. Always check whether the permission was granted before calling the
API; Amazon rejects skills that assume consent.

See [Account Linking Concepts](https://developer.amazon.com/en-US/docs/alexa/account-linking/account-linking-concepts.html) and [Configure Permissions for Customer Information](https://developer.amazon.com/en-US/docs/alexa/custom-skills/configure-permissions-for-customer-information-in-your-skill.html).

## Versioning and safe change

Alexa uses a three-stage model: `development`, `certified`, and `live`. Edit the development
version freely; it's isolated from live until you explicitly promote.

**Workflow:** In the console, Code tab (Alexa-hosted only) or via `ask deploy` (self-hosted), you
edit and deploy to development. Once live, Amazon automatically creates a copy of the live version
back in development. You can then update the development version (interaction model, APL,
backend code) without affecting users of the live skill. When ready, promote development to live.

**Interaction model changes require rebuild:** If you update the interaction model (intents, slots,
utterances), you must click "Build Model" on the Build tab before the change takes effect. A
deployed backend against a stale model won't parse new utterances.

Rollback is available: the Skill Rollback feature lets you revert the live version to a previous
version if something breaks post-launch.

## Analytics and post-launch

The Analytics page in the developer console reports on skill usage.

**Metrics:** unique users, total sessions, utterances (grouped by intent), intents per session,
success/failure rates, account linking completion rate. You can export as PNG or CSV.

**Intent history:** View actual user speech transcriptions (aggregated and anonymized) mapped to
intents, including utterances the NLU didn't recognize. Use this to find misclassified utterances,
then add samples to your interaction model and re-build.

**NLU Evaluation Tool:** Test your utterance samples against the model before deploying. Upload a
test set and see which intents the model predicts. This catches obvious mismatches early.

**Data retention:** Historical analytics are available for up to 15 months.

See [Analyze Your Skill Metrics](https://developer.amazon.com/en-US/docs/alexa/devconsole/about-skill-metrics.html) and [Interpret Metrics](https://developer.amazon.com/en-US/docs/alexa/devconsole/interpret-metrics-results.html).

## Deprecations and platform churn

As of July 2026, note these retirements:

- **Alexa Developer Rewards Program** (July 1, 2024): no longer available. Monetize via in-skill
  purchasing or account linking instead.
- **Amazon Pay in skills** (date): removed. Use account linking + your own payment processor, or
  in-skill purchasing.
- **A/B Testing** (August 21, 2025): deprecated. Use beta testing or manual rollout strategies
  instead.
- **Alexa Business Skill API** (March 2023): retired. Use [Alexa Smart Properties](https://developer.amazon.com/en-US/alexa/alexasmartproperties) for enterprise multi-user skills.
- **Smart Home API v2** (November 1, 2025): Smart Home skills must use Smart Home API v3 going
  forward.

Alexa+ (the new platform for generative and conversational skills) has emerged as a distinct
publishing path as of July 2026; see the [Alexa+ documentation](https://developer.amazon.com/alexaplus/) for
current guidance if your skill involves LLM orchestration or conversational AI.

## Cross-links

- [Skill setup and tooling](skill-setup-and-tooling.md) — ASK CLI, deployment, local testing
- [Interaction model](interaction-model.md) — intents, slots, utterances
- [APL displays](apl-displays.md) — building and testing screen UI

## Sources

- [Alexa Developer Console](https://developer.amazon.com/alexa/console)
- [Submit Alexa Skills for Certification](https://developer.amazon.com/en-US/docs/alexa/devconsole/test-and-submit-your-skill.html)
- [Certification Requirements for Custom Skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/certification-requirements-for-custom-skills.html)
- [Skill Beta Testing for Alexa Skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/skills-beta-testing-for-alexa-skills.html)
- [Test Your Skill Overview](https://developer.amazon.com/en-US/docs/alexa/test/test-your-skill-overview.html)
- [Account Linking Concepts](https://developer.amazon.com/en-US/docs/alexa/account-linking/account-linking-concepts.html)
- [Configure Permissions for Customer Information](https://developer.amazon.com/en-US/docs/alexa/custom-skills/configure-permissions-for-customer-information-in-your-skill.html)
- [Analyze Your Skill Metrics](https://developer.amazon.com/en-US/docs/alexa/devconsole/about-skill-metrics.html)
- [Deprecated Features](https://developer.amazon.com/en-US/docs/alexa/ask-overviews/deprecated-features.html)
- [Alexa Smart Properties](https://developer.amazon.com/en-US/alexa/alexasmartproperties)
- [Alexa+ Documentation](https://developer.amazon.com/alexaplus/)
