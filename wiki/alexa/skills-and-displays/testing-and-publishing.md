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

Test cheaply first, push to hardware last. Each rung below names the command or tool to run and
what it does and doesn't prove.

| What | Cost | Catches | Misses |
|---|---|---|---|
| Unit tests (serde, request/response JSON) | Near-free | Request contract shape, handler logic, serialization | Real NLU matching, device latency, APL rendering |
| `ask dialog` + `ask simulate` | 1–2s per invocation | Multi-turn utterances, intent routing, speech output | APL display, touch behavior, real device quirks |
| Developer Console simulator | 1–2 clicks | Voice/text input, APL preview on multiple screen sizes, full JSON inspection | APL touch events, timing, performance under load, actual device rendering fidelity |
| APL Authoring Tool preview | Drag/drop + live | Component layout, responsiveness across viewports | On-device rendering, animations, tap zones at actual DPI, scrolling feel |
| Physical device (Echo Show) | Marginal | Pixel-perfect layout, touch hit zones, animations, actual response latency, real firmware behavior | Rare firmware/hardware bugs, full fleet behavior variance |

**Unit tests:** run your normal test suite (`cargo test`, `pytest`) against the serialized JSON your
handler produces and consumes. This catches a broken serde tag or a missing field before you ever
invoke Alexa. It proves nothing about whether Alexa's NLU will actually route an utterance to your
intent.

**`ask dialog` / `ask simulate` (ASK CLI):** `ask dialog -l en-US -s <skill-id>` gives you an
interactive text conversation against the deployed interaction model without touching a device;
`ask simulate -l en-US -s <skill-id> -t "your utterance"` runs a single turn and returns the full
response JSON. Both catch intent-routing and slot-filling problems fast, in a terminal, without
opening the console. Neither one renders APL or exercises touch.

**Developer Console simulator:** the console's built-in simulator (voice or text input) shows you
the JSON response and, for display skills, a preview of the APL document at several fixed viewport
profiles. Use it to check intent routing plus a first-pass look at layout across viewports before
you touch a device. It does not fire real `Alexa.Presentation.APL.UserEvent` touch events and its
rendering is an approximation, not the on-device renderer.

**APL Authoring Tool preview:** open your APL document in the Authoring Tool and switch between the
device-shape presets (round, landscape, portrait, hub) to check that your layout responds correctly
at each viewport profile, not just the one you designed against. This is the cheapest way to catch a
layout that only works at one screen size. It still isn't the on-device renderer, so animation
timing, tap-zone accuracy, and scroll feel are unverified until real hardware.

**Physical device (Echo Show):** required before certification for any skill with a display.
Validate touch hit zones against the visual boundary of each interactive component, play through
your animations at normal speed, and confirm response latency feels acceptable in a live
conversation. Also run every intent on a screenless device (an Echo or Echo Dot signed into the same
developer account): confirm `context.System.device.supportedInterfaces` reports no
`Alexa.Presentation.APL`, and that your handler falls back to voice or card output instead of trying
to render a directive the device can't display. Hardware testing won't surface rare firmware bugs or
behavior that varies across the installed fleet; that only shows up after wider distribution.

**Key caveat on the console simulator:** it is an approximation. The APL preview does not faithfully
reproduce on-device rendering quality, touch hit zones, animation timing, or gesture scrolling. A
skill with a display *must* be validated on real hardware before certification. Simulators catch
schema errors and obvious intent mismatches; they don't catch pixel-alignment bugs or touch-zone
dead zones that will frustrate users on an actual Show.

For a pure voice-only skill (no APL), the console simulator is sufficient for certification testing.
For any skill with a display, you need hardware, including a screenless device to confirm the
fallback path.

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

The full requirements live in Amazon's
[Certification Requirements for Custom Skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/certification-requirements-for-custom-skills.html);
don't retype it, but do run these checks against your actual build before you hit Submit, since
these are the ones that most often fail review.

**Run `AMAZON.HelpIntent`, `AMAZON.CancelIntent`, and `AMAZON.StopIntent` from every conversation
state.** These three are the baseline required intents for any custom skill. Say "help," "stop,"
and "cancel" mid-dialog, not just at the start, and confirm the skill responds sensibly and, for
Stop/Cancel, releases the session cleanly back to Alexa. A skill that only handles these at the
top-level invocation fails review the first time a reviewer interrupts a deeper conversation state.

**Say something your model doesn't recognize, and confirm `AMAZON.FallbackIntent` catches it.**
What actually fails certification isn't the intent's absence from your model (the console adds it
by default), it's an *unhandled* fallback: an out-of-domain utterance that throws an error or dead-
ends the session instead of getting a "sorry, I didn't catch that" response. Test with a handful of
utterances well outside your model's scope.

**`AMAZON.NavigateHomeIntent`: declare it, don't write a handler.** Amazon's own documentation
disagrees with itself here. The
[Standard Built-in Intents reference](https://developer.amazon.com/en-US/docs/alexa/custom-skills/standard-built-in-intents.html)
lists it under intents for screen-capable devices with "Skill Developer Handles Intent? No," meaning
Alexa intercepts it on-device and ends the session before your code runs. The
[Tips for Using Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/interaction-model-design/tips-for-using-built-in-intents-for-your-skill.html)
page calls it "another required Built-in Intent" without that qualifier. Since declaring it in your
interaction model costs nothing and Alexa handles the behavior for you, declare it if your skill has
a display or multimodal component; don't spend time writing a handler for it.

**Say your invocation name out loud to someone who has never heard it.** Lowercase, one or two
words, no ordinal words ("first," "second"), no leading article. If it's easily confused with a
built-in skill name or an Amazon brand, reviewers will bounce it.

**Trigger every intent from a screenless device.** Sign into an Echo or Echo Dot (no display) with
the same developer account, invoke the skill, and run through your intents. Check
`context.System.device.supportedInterfaces` for `Alexa.Presentation.APL`; if it's absent, your
handler must fall back to voice or card output, never throw an error or assume a display exists.

**Load your privacy policy and terms URLs in a private browser tab.** They must return HTTP 200
with no login wall, and must actually describe what your skill does with user data. Amazon's review
loads and reads them the same way; a broken or gated link is an automatic bounce. Host them
somewhere you control, not a third-party wiki that might disappear.

**Diff your permissions manifest against what your code actually calls.** Every permission you
request (device address, customer profile, notifications) needs a matching consent-check in your
handler code before you call the corresponding API. Requesting a permission you don't use, or using
one without checking consent first, both fail review.

**If your skill is child-directed, verify the COPPA checklist, not just the metadata flag.** No
third-party ads or tracking, no personalization without verifiable parental consent. Amazon audits
the claim, not just the checkbox.

**If you use account linking, test the authorization flow against a fresh test account.** See
[Account linking and permissions](#account-linking-and-permissions) below for the response-time and
token-lifetime requirements to verify.

## Distribution options

| Path | Certification | Account | Access | Use case |
|---|---|---|---|---|
| Development (your account only) | No | Your Amazon dev account | Your own Echo devices | Personal project, prototype |
| Beta testing | No | Your Amazon dev account | Up to 500 invited testers | Small group, pre-launch feedback |
| Alexa Smart Properties | Depends | Enterprise/property contract | Property-fleet devices | Senior living and hospitality room/property fleets |
| Public Store | Yes | Your Amazon dev account | Any Alexa user, global discovery | Public release, monetization |

**Development stage** is the default. A skill in development is automatically enabled on every
Alexa device signed into the same Amazon account that created it. No publishing, no review, no
beta invite needed. If you want a personal dashboard on your own Show, this is all you need.

**Alexa Smart Properties is not a general enterprise-distribution mechanism.** Amazon documents and
markets it specifically for two verticals: senior living communities and hospitality (guest-room
voice services), sold as a property-fleet management contract, not a way to push an arbitrary skill
to a company's office devices. It is also the named successor to the old Alexa for Business calendar
and meeting-room features: the [Alexa Business Skill API](https://developer.amazon.com/en-US/docs/alexa/ask-overviews/deprecated-features.html)
(the `Alexa.Calendar` and `Alexa.MeetingClientController` interfaces) was retired as of March 2023,
and Amazon's own deprecation notice points developers toward Smart Property APIs for that narrower
business-features case, not toward Smart Properties as a general private-distribution channel. See
[Alexa Smart Properties](https://developer.amazon.com/en-US/alexa/alexasmartproperties).

**If you need this for a handful of named people inside a company,** the real options are narrower
than they look. Beta testing covers up to 500 people by email invite and costs nothing, but the test
automatically ends after 90 days and each tester must enroll within 30 days or get auto-removed, so
it's a testing mechanism, not a standing internal-distribution channel; you'd have to re-open a test
every three months. Development stage covers only devices signed into the single Amazon account that
created the skill, so it doesn't scale past one person unless everyone shares that account, which
creates its own problems (shared credentials, no per-user account linking). There is no first-party
mechanism, as of July 2026, for "install this custom skill permanently for a named list of employees
without certifying it publicly." If that's a hard requirement, the realistic paths are: run a beta
test and simply keep renewing it every 90 days, or certify to the Public Store and rely on the
invocation name and your own access control (account linking, an allowlist in your backend) rather
than distribution-level gating.

**Public Store** requires certification and gives you global discoverability. Amazon doesn't publish
a fixed review turnaround; you get an email when the review completes and can track status in the
console's Version History. Amazon reviews the skill against the checklist above and can iterate with
questions. Once certified, a new development version is automatically created so you can continue
iterating without affecting the live skill.

## Account linking and permissions

When your skill needs a real user identity (to look up their data from an external system, for
example), you declare this via **account linking** in the skill metadata.

**OAuth2 flow:** Alexa acts as the OAuth2 client. When a user enables your skill, the Alexa app
directs them to your authorization server (your own login page or a third-party service like Auth0).
After they authenticate and consent, your server returns an access token to Amazon, which stores it.
On each skill invocation, the request includes the access token in `context.System.user.permissions.consentToken`.

Amazon recommends the **authorization code grant** (with refresh token) over implicit grant because
it allows Alexa to renew the token without user re-authentication. Support for PKCE (Proof Key for
Code Exchange) is available for added security. Your authorization server must respond to the
access token request within 4.5 seconds and use HTTPS with a certificate from an Amazon-approved CA.

**Token lifetime: Amazon's own pages disagree, so check both before you pick a number.** The
[Account Linking FAQ](https://developer.amazon.com/docs/alexaplus/account-linking/faq.html) states
access tokens "must have a lifetime of at least six minutes (360 seconds)." That's a floor on how
long the token stays valid once issued, not a deadline for your server to return it. The
[Requirements for Account Linking](https://developer.amazon.com/en-US/docs/alexa/account-linking/requirements-account-linking.html)
page separately recommends setting the access token TTL to at least one hour (3600 seconds), and the
refresh token TTL to at least 180 days or never. The two pages give different minimums, six minutes
is the documented floor, one hour is Amazon's own recommendation on a different page. Set your TTL
to at least an hour and you satisfy both.

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
deployed backend against a stale model won't parse new utterances, and this is a separate step from
deploying your backend code, so it's easy to ship a backend that expects a new intent that the live
model doesn't know about yet.

**What actually breaks when you change a live skill:**

- **Backend code changes** take effect on the next invocation. A session already in progress when
  you deploy keeps running against whatever code was handling it; Lambda doesn't hot-swap code under
  an in-flight execution. New sessions get the new code immediately, there's no gradual rollout.
- **Removing an intent** from the interaction model doesn't retroactively break an existing session,
  but the next utterance a user says that used to match the removed intent now falls through to
  `AMAZON.FallbackIntent` (or errors, if you haven't handled Fallback, see the checklist above).
  Removing an intent your backend still expects to dispatch on is a silent no-op until someone
  triggers it and finds the code path unreachable.
- **An interaction model change needs the rebuild step before any of it is live**, per above. Until
  you click Build Model, the deployed model, not your edited one, is what Alexa's NLU actually
  matches against, no matter what your backend code assumes.

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
- **Amazon Pay in skills**: removed. Amazon's
  [Deprecated Features](https://developer.amazon.com/en-US/docs/alexa/ask-overviews/deprecated-features.html)
  page confirms the functionality is no longer available but publishes no retirement date; don't
  trust a specific date from secondary sources, since they disagree with each other. Use account
  linking with your own payment processor, or in-skill purchasing.
- **A/B Testing** (August 21, 2025): deprecated. Use beta testing or manual rollout strategies
  instead.
- **Alexa Business Skill API** (March 2023): retired, removing the `Alexa.Calendar` and
  `Alexa.MeetingClientController` interfaces. Amazon's own notice points developers toward Smart
  Property APIs as the replacement for that narrower business-features case, not toward
  [Alexa Smart Properties](https://developer.amazon.com/en-US/alexa/alexasmartproperties) as a
  general enterprise-distribution channel; see the distribution table above.
- **Smart Home API v2** (November 1, 2025): Smart Home skills must use Smart Home API v3 going
  forward.

**Alexa+** is Amazon's newer conversational/generative assistant platform. The announcement-era
naming from February 2025 (an Action SDK, a Web Action SDK, and a Multi-Agent SDK) has since
changed; current builder material names a different toolkit lineup (a Category SDK, an MCP Toolkit,
and a smart-home AI toolkit). As of July 2026 it's described as open to selected partners, not
generally available, so it isn't a path a new project can simply choose today. Classic custom skills
with ASK and APL remain supported and remain the right path for a project of this shape. See the
[Alexa+ developer page](https://developer.amazon.com/alexaplus/) for current guidance if that
changes for your use case.

## Cross-links

- [Skill setup and tooling](skill-setup-and-tooling.md): ASK CLI, deployment, local testing
- [Interaction model](interaction-model.md): intents, slots, utterances
- [APL displays](apl-displays.md): building and testing screen UI

## Sources

- [Alexa Developer Console](https://developer.amazon.com/alexa/console)
- [Submit Alexa Skills for Certification](https://developer.amazon.com/en-US/docs/alexa/devconsole/test-and-submit-your-skill.html)
- [Certification Requirements for Custom Skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/certification-requirements-for-custom-skills.html)
- [Skill Beta Testing for Alexa Skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/skills-beta-testing-for-alexa-skills.html)
- [Test Your Skill Overview](https://developer.amazon.com/en-US/docs/alexa/test/test-your-skill-overview.html)
- [Account Linking Concepts](https://developer.amazon.com/en-US/docs/alexa/account-linking/account-linking-concepts.html)
- [Requirements for Account Linking](https://developer.amazon.com/en-US/docs/alexa/account-linking/requirements-account-linking.html)
- [Account Linking FAQ (Alexa+)](https://developer.amazon.com/docs/alexaplus/account-linking/faq.html)
- [Configure Permissions for Customer Information](https://developer.amazon.com/en-US/docs/alexa/custom-skills/configure-permissions-for-customer-information-in-your-skill.html)
- [Standard Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/custom-skills/standard-built-in-intents.html)
- [Tips for Using Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/interaction-model-design/tips-for-using-built-in-intents-for-your-skill.html)
- [Analyze Your Skill Metrics](https://developer.amazon.com/en-US/docs/alexa/devconsole/about-skill-metrics.html)
- [Deprecated Features](https://developer.amazon.com/en-US/docs/alexa/ask-overviews/deprecated-features.html)
- [Alexa Smart Properties](https://developer.amazon.com/en-US/alexa/alexasmartproperties)
- [Alexa+ Documentation](https://developer.amazon.com/alexaplus/)
