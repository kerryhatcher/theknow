---
description: What a custom Alexa skill with an Echo Show display actually is, the constraints that shape every design decision, and where to start.
---

# Alexa skills and Echo Show UIs

A custom Alexa skill that also drives a screen on an Echo Show is five separate pieces
glued together by a request/response contract, not one app. This section is a route
through those pieces for an engineer who knows AWS and backend work but has never
touched Alexa: what each piece is, the constraints that make the design non-negotiable,
a recommended architecture, and the order to build it in. **Current as of July 2026.**
The platform is genuinely in flux right now (Alexa+ rolled out new SDKs in 2025, APL and
the ASK CLI keep shipping quarterly, crate versions move monthly), so re-verify anything
load-bearing, especially version numbers and quotas, before you build on it.

## Start here: the five moving parts

<table><thead><tr><th width="140">Part</th><th>What it is</th><th>Where it lives</th><th>Page</th></tr></thead><tbody>
<tr><td><strong>The skill</strong></td><td>Manifest (<code>skill.json</code>) plus interaction model: invocation name, intents, slots, utterances. What Alexa's NLU matches speech against.</td><td>Developer Console or JSON in Git, deployed with the ASK CLI.</td><td><a href="skill-setup-and-tooling.md">Setup and tooling</a>, <a href="interaction-model.md">Interaction model</a></td></tr>
<tr><td><strong>The voice layer</strong></td><td>ASR and NLU, run entirely by Alexa's cloud before your code executes. Turns audio into a typed <code>IntentRequest</code>.</td><td>Amazon's infrastructure, not yours.</td><td><a href="interaction-model.md">Interaction model</a></td></tr>
<tr><td><strong>The display layer</strong></td><td>APL: a JSON document plus a datasource, rendered by an on-device engine. Conditional, not guaranteed.</td><td>APL Editor in the console, or authored as JSON in your repo.</td><td><a href="apl-displays.md">APL displays</a></td></tr>
<tr><td><strong>The fulfillment endpoint</strong></td><td>Your backend. Receives the request envelope, returns speech plus optional directives within the response budget.</td><td>AWS Lambda (recommended) or a self-hosted HTTPS server.</td><td><a href="backend-rust.md">Backend in Rust</a></td></tr>
<tr><td><strong>The data/model layer</strong></td><td>Whatever supplies the actual numbers: a database, an API, or an LLM call (Bedrock) that phrases and structures them.</td><td>Inside your fulfillment Lambda, or a store it queries.</td><td><a href="ai-integration.md">AI integration</a></td></tr>
</tbody></table>

## The constraints that dominate the design

Read this before you design anything. Every sibling page returns to these.

- **The response budget is roughly 8 seconds, and it is not negotiable.** That is Amazon's
  own documented figure, not a hard published SLA, and ASR/NLU already eat 1-2 seconds of it
  before your Lambda even starts. Realistic remaining budget for your code plus a model call
  is closer to 3-5 seconds. Miss it and the user hears a generic error or silence, with no
  detail in your logs. See [AI integration](ai-integration.md#the-response-budget).
- **The same skill runs on screenless devices, so display is always conditional.** A
  development-stage skill is enabled on every device on the account that created it,
  Echo Dot included. Check `context.System.device.supportedInterfaces` for
  `Alexa.Presentation.APL` before sending a `RenderDocument` directive, always populate
  `outputSpeech` regardless, and do it in one shared response-builder, not per intent
  handler. See [APL displays](apl-displays.md#detect-the-screen-before-you-send-it).
- **A development-stage skill needs no certification, but only runs on your own account.**
  No review, no waiting, but "your own account" means every device signed into it, not a
  secret single device. Certification (5+ business days of review) is only required to
  reach the public Alexa Skills Store. Beta testing sits in between, up to 500 invited
  testers, no certification. See
  [Setup and tooling](skill-setup-and-tooling.md#skill-stages-and-who-can-use-them) and
  [Testing and publishing](testing-and-publishing.md#beta-testing).
- **Rust has no official SDK.** Node.js, Python, and Java get an Amazon-maintained
  `ask-sdk`. Rust gets `lambda_runtime` for the Lambda plumbing and hand-rolled `serde`
  structs for the request/response contract; the one community crate (`alexa_sdk`) is six
  years stale with no APL support. Budget for structs, not a port. Alexa-hosted skills
  cannot run Rust at all, only Node.js or Python; Rust requires your own AWS Lambda. See
  [Backend in Rust](backend-rust.md#the-crate-landscape).

## Recommended architecture

Put a Rust Lambda directly behind the Alexa Skills Kit trigger, so Amazon owns transport
auth and TLS and you never touch request signing. Inside the handler: verify the skill ID,
dispatch on `request.type`, and for anything that needs real data, fetch it yourself before
calling a model, then hand the model only the numbers and ask it to phrase a short sentence
and a typed display payload in one structured call (Bedrock's Converse API with a forced
tool call is the reliable way to get both shapes back from one request). Wrap that model call
in an explicit timeout and fall back to a canned response rather than let it eat the whole
budget. Keep per-turn state in `sessionAttributes`; anything that needs to survive past the
session goes in DynamoDB. Work genuinely too slow for 8 seconds moves out of the turn entirely
through an async worker and the Proactive Events API, not through a longer wait.

```
Echo Show ── mic/touch ──> Alexa cloud (ASR/NLU) ── IntentRequest/UserEvent ──> Lambda
                                                                                  │
                                                    ┌─────────────────────────────┼──────────────┐
                                                    ▼                             ▼              ▼
                                            your data source               Bedrock Converse   DynamoDB
                                            (fetch first, always)         (phrase + structure)  (session/prefs)
                                                    │                             │
                                                    └──────────────┬──────────────┘
                                                                   ▼
                                                  outputSpeech + conditional RenderDocument
                                                                   │
                                                                   ▼
                                                          Echo Show / screenless Echo
```

This matches the reference architecture and latency guidance in
[AI integration](ai-integration.md#reference-architecture), and the Lambda-first, verify-the-
skill-ID posture in [Backend in Rust](backend-rust.md#lambda-still-owes-you-one-check).

## First week: build in this order

1. **`ask new`**, Custom skill, self-hosted Lambda, and get one intent round-tripping
   through the console simulator with plain-text speech. No display, no model, no real data.
2. **Put a hardcoded APL document on a real Echo Show.** Skip the model and your own data
   entirely, one `RenderDocument` with static numbers, driven by the same intent. The
   console preview does not faithfully reproduce on-device rendering, so get onto hardware
   in week one, not right before certification.
3. **Wire up the real fulfillment backend**: the serde request/response structs, the
   skill-ID check, screen detection via `supportedInterfaces`, and a `TouchWrapper` that
   fires a real `SendEvent` back to your handler.
4. **Replace hardcoded numbers with your actual data source.** Still no model. Confirm the
   whole voice-plus-touch loop works end to end on real data before adding any AI latency
   to the budget.
5. **Add the model call last**, behind a timeout, with a canned fallback, structured output
   split into `speech` and `display`, and a prompt constrained against markdown. This is
   the step most likely to blow your response budget, do it once everything else is solid.

## What will bite you

- Shipping a `RenderDocument` unconditionally and finding it silently dropped, or a
  certification rejection, the first time someone runs the skill on an Echo Dot.
- Treating a custom slot type as an enforced enum. It biases the NLU, it doesn't restrict
  it; branch on the entity-resolution status, not the raw slot string, or your `match` will
  panic on production traffic.
- A multi-step agent loop (retrieval, then reasoning, then generation) that was fine in a
  chat UI. Each round-trip is additive, not overlapping, and three 1-2 second calls alone
  exceed the whole budget before you've produced a word.
- Putting the model in the data path ("look up the order status" inside the prompt) instead
  of fetching first and asking the model only to phrase the result.
- Forgetting the Lambda still needs its own skill-ID check even after the Alexa Skills Kit
  trigger is wired up; the trigger's scoping lives in a separate resource policy that's easy
  to leave off.
- A skill manifest pointing at the right Lambda ARN but no Alexa Skills Kit trigger granting
  invoke permission, the most common "why doesn't my skill respond at all" bug.
- Total response size (speech, directives, session attributes) capped at 24 KB; a large
  inline APL document plus a data-heavy datasource can hit that before you expect it.
- Assuming the Alexa+ generative SDKs (Action, Web Action, Multi-Agent) replace this stack.
  They target partner task-completion, not a skill with your own data and your own model;
  classic custom skills keep working in 2026, but re-check Amazon's current framing before
  betting a new project on either path.

## Pages

<table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody>
<tr><td><strong>Setup and tooling</strong></td><td>Accounts, skill stages, the ASK CLI, and hosting trade-offs.</td><td><a href="skill-setup-and-tooling.md">skill-setup-and-tooling.md</a></td></tr>
<tr><td><strong>Interaction model</strong></td><td>Invocation names, intents, slots, entity resolution, dialog, session state.</td><td><a href="interaction-model.md">interaction-model.md</a></td></tr>
<tr><td><strong>APL displays</strong></td><td>Rendering and driving a touchable screen with the Alexa Presentation Language.</td><td><a href="apl-displays.md">apl-displays.md</a></td></tr>
<tr><td><strong>Backend in Rust</strong></td><td>The fulfillment contract, serde modeling, and a working Lambda.</td><td><a href="backend-rust.md">backend-rust.md</a></td></tr>
<tr><td><strong>AI integration</strong></td><td>Fitting a model call into the response budget, plus structured output for speech and screen.</td><td><a href="ai-integration.md">ai-integration.md</a></td></tr>
<tr><td><strong>Testing and publishing</strong></td><td>The testing ladder, beta testing, certification, and distribution.</td><td><a href="testing-and-publishing.md">testing-and-publishing.md</a></td></tr>
</tbody></table>

## Sources

- [Understand Custom Skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/understanding-custom-skills.html), Amazon developer docs
- [Add Visuals and Audio to Your Skill](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/add-visuals-and-audio-to-your-skill.html), the current APL overview (the old `apl-overview.html` URL now redirects here)
- [ASK CLI Overview](https://developer.amazon.com/en-US/docs/alexa/smapi/ask-cli-intro.html), Amazon developer docs
- [Request and Response JSON Reference](https://developer.amazon.com/en-US/docs/alexa/custom-skills/request-and-response-json-reference.html), Amazon developer docs
- [Certification Requirements for Alexa Skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/certification-requirements-for-custom-skills.html), Amazon developer docs
- [Amazon Bedrock](https://aws.amazon.com/bedrock/), AWS
- [Alexa Skills Kit](https://developer.amazon.com/en-US/alexa/alexa-skills-kit), Amazon developer portal
- [cargo-lambda](https://www.cargo-lambda.info/), build/deploy tooling for Rust on Lambda
- [`lambda_runtime`](https://crates.io/crates/lambda_runtime), crates.io, the AWS-maintained Rust Lambda runtime
- [ask-sdk-python](https://github.com/alexa/alexa-skills-kit-sdk-for-python), GitHub, the officially supported Python SDK
