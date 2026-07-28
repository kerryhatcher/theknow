---
description: The fulfillment endpoint contract for a custom Alexa skill, and how to implement it in Rust on AWS Lambda.
---

# The fulfillment backend in Rust

Once a user talks to an Echo device, Alexa's cloud does the speech recognition and language
understanding and turns the utterance into a JSON request. That request gets POSTed to your
fulfillment endpoint. Your endpoint has about 8 seconds to return a JSON response containing
speech (and, on a screen device, a display directive). This page covers that endpoint: the
transport choice, the security you owe, the request/response contract, and a working Rust
Lambda that implements it.

## Lambda or HTTPS: decide this first

Use a Lambda function as your endpoint unless you have a concrete reason not to. The reason:
with Lambda, Alexa's service invokes your function directly through the Lambda service, not
over public HTTPS, so Amazon owns both the transport authentication and TLS. With a raw HTTPS
endpoint, Alexa POSTs to your URL like any other webhook caller, and you become responsible
for proving every incoming request actually came from Alexa. Skip that proof and anyone who
finds your URL can send forged requests your skill will happily act on.

<table><thead><tr><th></th><th>Lambda endpoint</th><th>HTTPS endpoint</th></tr></thead><tbody>
<tr><td>Transport auth</td><td>Handled by AWS IAM/STS invocation, nothing to verify</td><td>You verify the <code>SignatureCertChainUrl</code> chain and the request signature yourself</td></tr>
<tr><td>TLS</td><td>Not your problem</td><td>Your cert must chain to an Amazon-trusted CA; self-signed fails certification</td></tr>
<tr><td>Hosting</td><td>AWS owns scaling and availability</td><td>You run and patch a server</td></tr>
<tr><td>Language freedom</td><td>Any Lambda-supported runtime, including a custom Rust runtime</td><td>Any language, any framework</td></tr>
<tr><td>Cold starts</td><td>Real, budget for them (see below)</td><td>None, if the process stays warm</td></tr>
</tbody></table>

Pick HTTPS only if the fulfillment logic must live in an existing always-on service that
other callers also hit. Otherwise Lambda deletes an entire category of security code you'd
otherwise have to write and maintain. See the official comparison:
[Host a Custom Skill as a Web Service](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-a-web-service.html)
versus
[Host a Custom Skill as an AWS Lambda Function](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-an-aws-lambda-function.html).

{% hint style="warning" %}
If you do go HTTPS, the checklist is non-negotiable and enforced at certification: validate
that `SignatureCertChainUrl` points to `https://s3.amazonaws.com/echo.api/...`, fetch and
cache that cert chain, confirm the leaf certificate's SAN includes `echo-api.amazon.com`,
verify the `Signature-256` header against the raw request body, and reject anything where
`request.timestamp` is more than 150 seconds old. All five, every request. Details in the
web-service doc above.
{% endhint %}

## Let the Lambda trigger verify the Skill ID

Configure the Alexa Skills Kit trigger with skill-ID verification and your Skill ID. Amazon
recommends this setting: the Lambda resource policy then rejects requests from other skills
before the function runs, so the handler does not need to reimplement request verification.
Keep the trigger scoped to the skill when you deploy or replace the function; without it, the
function's resource policy can allow a broader set of Alexa invocations.

An in-handler `context.System.application.applicationId` check is useful only when you have
intentionally disabled trigger verification (for example, a test function shared by many
skills). Treat that as an exception and validate against an explicit allowlist before dispatch.
For a normal production skill, enable the trigger setting rather than relying on application
code as the enforcement boundary.

## The request and response contract

Every request is a JSON envelope: `version`, `session`, `context`, and `request`.
`request.type` discriminates what happened:

- **`LaunchRequest`**, the user opened the skill with no specific ask ("Alexa, open my skill").
- **`IntentRequest`**, the user said something matching a defined intent. Carries
  `request.intent.name` and `request.intent.slots`.
- **`SessionEndedRequest`**, the session is closing (timeout, "stop," or an error). You
  cannot return speech to it, just acknowledge with an empty response.
- **`Alexa.Presentation.APL.UserEvent`**, the user touched something on an APL document (a
  button, for example). Carries `request.arguments` and `request.source`.

Full field-by-field reference:
[Request and Response JSON Reference](https://developer.amazon.com/en-US/docs/alexa/custom-skills/request-and-response-json-reference.html).
Don't try to reproduce that page here; the shape matters more than the exhaustive field list,
and it changes by request type in ways a static doc dump won't help you reason about.

### Modeling it in serde

`request.type` is a textbook internally-tagged enum: one JSON object, one field
(`"type"`) picks the variant, the rest of the object's fields belong to that variant. That's
exactly what `#[serde(tag = "type")]` does, and it's the right tool here, not an
externally-tagged or untagged enum. Externally-tagged (serde's default for a plain enum)
would want `{"LaunchRequest": {...}}`, which isn't Alexa's shape. Untagged would work but
throws away the discriminator as a compile-time exhaustiveness check and degrades error
messages when a new request type shows up.

```rust
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RequestEnvelope {
    pub version: String,
    pub session: Option<Session>,
    pub context: Value,
    pub request: RequestBody,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Session {
    #[serde(default)]
    pub new: bool,
    pub session_id: String,
    #[serde(default)]
    pub attributes: HashMap<String, Value>,
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all_fields = "camelCase")]
pub enum RequestBody {
    LaunchRequest {
        request_id: String,
    },
    IntentRequest {
        request_id: String,
        intent: Intent,
    },
    SessionEndedRequest {
        request_id: String,
        reason: String,
    },
    #[serde(rename = "Alexa.Presentation.APL.UserEvent")]
    AplUserEvent {
        request_id: String,
        arguments: Vec<Value>,
        source: Value,
        token: String,
    },
    // Anything Alexa adds later deserializes here instead of failing the whole request.
    #[serde(other)]
    Unknown,
}

#[derive(Deserialize)]
pub struct Intent {
    pub name: String,
    #[serde(default)]
    pub slots: HashMap<String, Value>,
}
```

The `#[serde(other)]` catch-all is not decoration. Alexa adds request types over time
(APL UserEvent itself is one such addition), and without it a single unrecognized type fails
deserialization for the whole envelope instead of falling through to a default response.

Watch the attribute name. `rename_all` on a tagged enum only camel-cases the *variant* names
used as tag values, it does not touch the fields inside each struct variant. Alexa's tag
values are PascalCase (`"IntentRequest"`, not `"intentRequest"`), so `rename_all` here would
actually break the tag match while leaving `request_id` unrenamed and failing to match
`requestId`. `rename_all_fields` is the attribute that camel-cases the fields inside every
struct variant while leaving the variant names, and therefore the tag values, alone. That is
the one you want for this shape. Mixing the two up compiles fine and fails silently at
runtime, which is worse than a compile error, so it's worth getting the name right the first
time.

### The response side

The response side is where `Option` and `skip_serializing_if` matter, because Alexa's JSON
parser is strict about the shape it receives: a `null` where a field is simply absent, or an
unexpected key, can fail skill certification or get silently ignored depending on the field.
Every optional response field should serialize as *absent*, never as `null`.

```rust
#[derive(Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ResponseEnvelope {
    pub version: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub session_attributes: Option<HashMap<String, Value>>,
    pub response: ResponseBody,
}

#[derive(Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ResponseBody {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_speech: Option<OutputSpeech>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub card: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reprompt: Option<Value>,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub directives: Vec<Value>,
    // Omit entirely when responding to an APL UserEvent; including it can
    // conflict with the display's own session-state expectations.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub should_end_session: Option<bool>,
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all_fields = "camelCase")]
pub enum OutputSpeech {
    PlainText { text: String },
    // Caller supplies the markup already wrapped in <speak>...</speak>; Alexa's
    // parser rejects SSML without the root element.
    #[serde(rename = "SSML")]
    Ssml { ssml: String },
}
```

An `OutputSpeech` value only ever needs one of these two shapes, so an enum tagged on `type`
models the contract directly instead of carrying a `speech_type` field that has to be kept in
sync with which text field is actually populated. `PlainText` serializes its payload under
`text`; the SSML variant serializes under `ssml`, matching Alexa's response contract, where
`outputSpeech.text` is only valid alongside `"type": "PlainText"` and `outputSpeech.ssml` is
only valid alongside `"type": "SSML"`. A struct with a single hard-coded `text` field cannot
express the SSML case at all, no matter what `speech_type` says.

`directives` and `card` stay as `serde_json::Value` on purpose. The APL document schema is
large, versioned, and usually built from a template with a few substituted values, so a full
Rust struct model buys little; see [APL displays](apl-displays.md) for the document shape
itself. Type the fields you branch your logic on (`request`, `intent.name`, slots), and leave
the fields you only pass through as `Value`. Mixing both in one struct is normal.

## The crate landscape

Checked directly on crates.io and docs.rs, not from memory, July 2026.

| Crate | Version (July 2026) | Last release | Verdict |
|---|---|---|---|
| [`lambda_runtime`](https://crates.io/crates/lambda_runtime) | 1.3.0 | 2026-07-09 | Use it. AWS-maintained, actively released, this is the standard way to run Rust on Lambda. |
| [`aws_lambda_events`](https://crates.io/crates/aws_lambda_events) | 1.2.0 | 2026-05-08 | Skip for this use case. It types API Gateway/ALB/SQS-style events; Alexa invokes Lambda directly with its own JSON shape, not through one of these event sources. |
| [`alexa_sdk`](https://crates.io/crates/alexa_sdk) | 0.1.5 | 2020-01-02 | Don't depend on it. Six years stale, ~20% doc coverage on docs.rs, only two structs (`Request`/`Response`), and **no APL support at all**, no directive types, nothing for `Alexa.Presentation.APL.UserEvent`. |
| `cargo-lambda` (CLI, not a crate) | current per [cargo-lambda.info](https://www.cargo-lambda.info/) | active | Use it for build/deploy/local-invoke tooling, covered below. |

There is no official Amazon-published Rust SDK for the Alexa Skills Kit, unlike the official
SDKs for Node.js, Python, and Java. Given `alexa_sdk`'s staleness and missing APL support,
hand-rolled serde structs like the ones above are the normal answer for a Rust skill backend
in 2026, not a stopgap. If you're coming from Python, the officially supported
[`ask-sdk-python`](https://github.com/alexa/alexa-skills-kit-sdk-for-python) gives you a
request/response object model and dispatches to handlers you register on a `SkillBuilder`
with `@sb.request_handler(can_handle_func=...)`, decorator-based routing that Rust simply has
no equivalent for. Node.js has the matching official `ask-sdk` package. Rust has neither;
budget for the structs above instead of hunting for a port.

## A minimal end-to-end Lambda

`Cargo.toml`, versions verified on crates.io at time of writing:

```toml
[dependencies]
lambda_runtime = "1.3"
tokio = { version = "1", features = ["macros"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tracing = "0.1"
tracing-subscriber = "0.3"
```

`main.rs`, dispatching on request type and returning speech plus a conditional APL directive:

```rust
use lambda_runtime::{run, service_fn, Error, LambdaEvent};
use serde_json::{json, Value};

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt().json().init();
    run(service_fn(handler)).await
}

async fn handler(event: LambdaEvent<Value>) -> Result<Value, Error> {
    let envelope = event.payload;

    let request_type = envelope["request"]["type"].as_str().unwrap_or_default();

    Ok(match request_type {
        "LaunchRequest" => launch_response(),
        "IntentRequest" => {
            let intent_name = envelope["request"]["intent"]["name"].as_str().unwrap_or_default();
            match intent_name {
                "ShowStatusIntent" => show_status_response(&envelope),
                "AMAZON.StopIntent" | "AMAZON.CancelIntent" => end_response("Goodbye!"),
                _ => end_response("Sorry, I didn't understand that."),
            }
        }
        "SessionEndedRequest" => json!({ "version": "1.0", "response": {} }),
        "Alexa.Presentation.APL.UserEvent" => handle_apl_event(&envelope),
        _ => end_response("Sorry, I can't do that yet."),
    })
}

fn launch_response() -> Value {
    json!({
        "version": "1.0",
        "response": {
            "outputSpeech": { "type": "PlainText", "text": "Welcome. Say show status." },
            "shouldEndSession": false
        }
    })
}

// Every request carries context.System.device.supportedInterfaces; a screenless Echo
// simply omits the Alexa.Presentation.APL key. See the same check in APL displays.
fn has_display(envelope: &Value) -> bool {
    envelope["context"]["System"]["device"]["supportedInterfaces"]
        .get("Alexa.Presentation.APL")
        .is_some()
}

fn show_status_response(envelope: &Value) -> Value {
    let mut directives = Vec::new();
    if has_display(envelope) {
        directives.push(json!({
            "type": "Alexa.Presentation.APL.RenderDocument",
            "token": "statusToken",
            "document": { "type": "APL", "version": "2024.3", "mainTemplate": { "items": [
                { "type": "Text", "text": "System status: OK", "fontSize": "48dp" }
            ] } },
            "datasources": {}
        }));
    }
    json!({
        "version": "1.0",
        "response": {
            "outputSpeech": { "type": "PlainText", "text": "Here's the current status." },
            "directives": directives,
            "shouldEndSession": false
        }
    })
}

fn handle_apl_event(envelope: &Value) -> Value {
    let source_id = envelope["request"]["source"]["id"].as_str().unwrap_or_default();
    end_response(&format!("You touched {}.", source_id))
}

fn end_response(speech: &str) -> Value {
    json!({
        "version": "1.0",
        "response": {
            "outputSpeech": { "type": "PlainText", "text": speech },
            "shouldEndSession": true
        }
    })
}
```

This sketch uses `serde_json::Value` throughout rather than the typed structs above, to keep
the example short. Swap in `RequestEnvelope`/`ResponseEnvelope` once the match arms outgrow a
handful of intents; see [Interaction model](interaction-model.md) for how the intent set
itself is defined.

### Build and deploy

Build and deploy with [cargo-lambda](https://www.cargo-lambda.info/):

```bash
cargo lambda build --release --arm64
cargo lambda deploy --iam-role <your-lambda-execution-role-arn>
```

`cargo lambda build` cross-compiles the binary to Linux and names it `bootstrap`, the file
name Lambda's custom runtime expects; `--arm64` targets Graviton instead of x86_64. The
runtime identifier itself, `provided.al2023`, is not something the build step chooses, it's
set on the Lambda function at deploy time. `cargo lambda deploy` uploads the built binary,
creating the function with that runtime on first run and updating its code on subsequent runs
([cargo-lambda deploy docs](https://www.cargo-lambda.info/commands/deploy.html)). Omit
`--iam-role` and cargo-lambda creates a basic execution role for you; pass one once you need
broader permissions (Secrets Manager, Bedrock, and so on). There's also a manual
`zip`-and-upload path if you'd rather not add the tool, but cargo-lambda is the maintained way
to do this and handles the `bootstrap` binary naming for you.

## Deployment wiring

Two places need to agree, and a mismatch here is the most common "why doesn't my skill
respond" bug:

1. The skill manifest's endpoint (in the developer console, or in `skill.json` if you manage
   it as code) points at your Lambda's ARN.
2. The Lambda itself needs an **Alexa Skills Kit trigger**, which adds a resource-based policy
   statement granting `alexa-appkit.amazon.com` permission to invoke the function, scoped to
   your Skill ID if you set skill ID verification on the trigger. Without this trigger, the
   invocation from Alexa's side is simply denied, regardless of what the manifest says.

Point the manifest at a specific Lambda **version or alias ARN**, not the bare function ARN,
which always resolves to `$LATEST`. `cargo lambda deploy` publishes new code to `$LATEST` on
every run, so wiring the manifest to `$LATEST` means a mid-development deploy can change a
live skill's behavior out from under you. Publish a version and point an alias at it instead,
then move the alias forward once you've tested the new code
([Host a Custom Skill as an AWS Lambda Function](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-an-aws-lambda-function.html)).

Prefer arm64 (Graviton) over x86_64 for both cost and cold-start latency; Rust's small binary
size means the difference is more pronounced than for a JVM or Node function with heavy
dependencies, but it's still real. For a skill that can't tolerate an occasional slow cold
start, AWS Lambda's Provisioned Concurrency keeps a set number of execution environments
warm; it costs money whether or not it's invoked, so reach for it only once cold starts are an
observed problem, not a precaution.

{% hint style="warning" %}
A new Lambda function's timeout defaults to **3 seconds**
([AWS Lambda timeout configuration](https://docs.aws.amazon.com/lambda/latest/dg/configuration-timeout.html)),
well under Alexa's own roughly 8-second response budget. Amazon's own guidance for
Lambda-backed skills is to raise the timeout to at least 8 seconds
([Alexa Lambda troubleshooting guide](https://developer.amazon.com/en-US/docs/alexa/smarthome/troubleshooting-guide.html)).
Leave the default and your function gets killed by AWS before Alexa's own timeout ever fires,
and from the user's side that failure looks identical to a slow handler, a support dead end
with no useful signal in your own logs about why. Set it explicitly; don't rely on the
default.
{% endhint %}

Cold starts matter specifically because Alexa's own timeout budget is fixed at roughly 8
seconds end to end, and a cold start eats into the same budget that an AI-agent call would
need; see [AI integration](ai-integration.md) for how that budget gets split when the
fulfillment logic calls out to a model.

## Error handling

If your Lambda times out or throws, Alexa doesn't retry indefinitely and doesn't show a
stack trace. It speaks a generic error message to the user and ends the session, no useful
detail passed through. That's a bad user experience but more importantly it's a support
dead end, because you learn nothing about what happened from the user's side.

The fix is structural: never let an unhandled error propagate out of the handler as a
returned `Err`. Catch every failure path inside your own code and return a valid response
with real speech instead, even if that speech is just an apology. The catch-all pattern above
(`end_response("Sorry, something went wrong.")` on the skill-ID mismatch, `_ =>
end_response(...)` on unrecognized request types and intents) is the general shape: exhaust
your `match` arms with a fallback that speaks, not one that returns `Err`. Reserve an actual
`Err` return from the handler for cases you want Lambda's own retry/monitoring behavior on,
which for a synchronous voice response is close to never.

This only covers a returned error, not a panic. A panic inside the handler future does not
produce a response at all, graceful or otherwise, it hangs the invocation until Alexa's own
timeout fires and the user hears Alexa's generic "is not responding" message instead of your
apology
([`aws-lambda-rust-runtime` issue #221](https://github.com/aws/aws-lambda-rust-runtime/issues/221)).
The example above avoids this by using `.unwrap_or_default()` everywhere instead of
`.unwrap()`/`.expect()`, which cannot panic on missing or wrong-shaped JSON. Keep that
discipline as your handler logic grows: treat `unwrap`/`expect` in the handler path as a bug,
not a shortcut, and route anything that can fail through `Result` and your own fallback
speech instead.

## Local development and testing

`cargo lambda watch` starts a local emulator of the Lambda control plane and hot-recompiles
on changes; `cargo lambda invoke` sends a payload to it (or to a deployed function with
`--remote`). Point it at a captured request JSON:

```bash
cargo lambda watch &
cargo lambda invoke your-function-name --data-file test-requests/launch-request.json
```

([cargo-lambda invoke docs](https://www.cargo-lambda.info/commands/invoke.html).) For real
request payloads to capture and replay, the Alexa developer console's **Test** tab shows the
exact JSON request and response for each utterance you try, and is the easiest source of a
realistic fixture set covering all four request types. See
[Skill setup and tooling](skill-setup-and-tooling.md) for getting the console test tab and a
build pipeline running in the first place.

## Observability

CloudWatch Logs is where your Lambda's `tracing` output and any panics land, and the developer
console's own request/response log (under the skill's Test or Analytics views) separately
shows what Alexa actually sent and received for a given session, which is useful for
diagnosing a mismatch between what you logged and what Alexa's parser accepted.

Log request type, intent name, and your own decision points freely. Do not log the raw
utterance text or the `userId`/`deviceId` values; both are personal data under Alexa's own
developer policies, and a debug log is not the place to accumulate them. If you need to
correlate a session across log lines, use `sessionId`, which is scoped to one conversation
and not tied to a person the way a stable `userId` is.

## See also

- [Skill setup and tooling](skill-setup-and-tooling.md), console setup, manifest, and build
  pipeline this endpoint plugs into.
- [Interaction model](interaction-model.md), how intents and slots are defined upstream of
  the `IntentRequest` this page parses.
- [APL displays](apl-displays.md), the document schema behind the `directives` field.
- [AI integration](ai-integration.md), what happens when the handler calls out to a model
  before it can answer, and how that fits the same latency budget as a cold start.

## Sources

- [Host a Custom Skill as an AWS Lambda Function](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-an-aws-lambda-function.html), Amazon developer docs.
- [Host a Custom Skill as a Web Service](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-a-web-service.html), Amazon developer docs. Signature/cert-chain/timestamp requirements.
- [Request and Response JSON Reference](https://developer.amazon.com/en-US/docs/alexa/custom-skills/request-and-response-json-reference.html), Amazon developer docs.
- [`lambda_runtime`](https://crates.io/crates/lambda_runtime), crates.io, checked July 2026 (v1.3.0, released 2026-07-09).
- [`aws_lambda_events`](https://crates.io/crates/aws_lambda_events), crates.io, checked July 2026 (v1.2.0).
- [`alexa_sdk`](https://crates.io/crates/alexa_sdk) / [docs.rs](https://docs.rs/alexa_sdk/latest/alexa_sdk/), checked July 2026 (v0.1.5, last released 2020-01-02).
- [`aws-lambda-rust-runtime`](https://github.com/awslabs/aws-lambda-rust-runtime), GitHub, AWS-maintained.
- [cargo-lambda documentation](https://www.cargo-lambda.info/), build/deploy/watch/invoke commands.
- [ask-sdk-python](https://github.com/alexa/alexa-skills-kit-sdk-for-python), the officially supported Python SDK.
- [`aws-lambda-rust-runtime` issue #221](https://github.com/aws/aws-lambda-rust-runtime/issues/221), a panicking handler hangs the invocation instead of returning a response.
- [AWS Lambda function timeout configuration](https://docs.aws.amazon.com/lambda/latest/dg/configuration-timeout.html), default is 3 seconds.
- [Alexa Lambda troubleshooting guide](https://developer.amazon.com/en-US/docs/alexa/smarthome/troubleshooting-guide.html), Amazon's recommendation to raise the timeout to at least 8 seconds.
