---
description: How to render and drive a touchable screen UI on an Echo Show with the Alexa Presentation Language, from RenderDocument to the touch-to-UserEvent loop.
---

# Screen UI with APL

Alexa Presentation Language (APL) is the JSON layout format Alexa's own client renders on a
screen device. It is not HTML, not a WebView, and not a general-purpose UI framework, it's
closer to a constrained cross between CSS flexbox and a native mobile layout DSL: a document
declares components and styles, a datasource supplies the values, and the same on-device APL
engine (Echo Show, Fire TV, Fire tablet) lays it out and paints it. You never ship a renderer,
you ship JSON an existing renderer interprets.

As of July 2026 the current release is **APL 2024.3**, versioned by year/quarter since APL
1.9. There is no successor language and no deprecation notice: APL is the only supported way
to put a graphical, touchable UI on an Echo device, and it keeps getting features (2024.3
added the `ImportPackage` command for lazy package loading, the `FlexSequence` component, and
new string data-binding functions). Alexa+, the 2025 generative-assistant overhaul, changes
how the built-in Alexa experience talks to you, it does not replace APL as the custom-skill
display layer. Target 2024.3 for a new project and move on. (Source:
[What's New in APL 2024.3](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-latest-version.html))

## The document/datasource split

An APL response is always two JSON objects, not one:

- **`document`**, the static layout: components, styles, named layouts, resource dimens. It
  describes structure and appearance, never the actual numbers or strings a user sees.
- **`datasources`**, the data you inject, bound into the document through
  `mainTemplate.parameters` and `${payload...}` expressions.

This split exists so the expensive part (the document, potentially large, reused across
requests) is cacheable, while the cheap part (a small data blob) changes on every turn. Host a
document or package once at a URL you control (there is no developer-console upload feature
for this, you self-host the JSON over HTTPS, S3 works fine), or reference an Amazon-maintained
package like `alexa-layouts` by name, or ship it inline. On every later render you send only
fresh `datasources` against the same document reference. That's the whole reason APL data
binding exists instead of templating a full JSON tree in your backend on every turn, and it
keeps your backend logic close to "build a data object," a much easier thing to unit test than
"build a UI tree." (Source: [APL Package](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-package.html))

The directive that carries both pieces to the device is
`Alexa.Presentation.APL.RenderDocument`:

```json
{
  "type": "Alexa.Presentation.APL.RenderDocument",
  "token": "metricDashboard",
  "document": {
    "type": "APL",
    "version": "2024.3",
    "import": [{ "name": "alexa-layouts", "version": "1.7.0" }],
    "mainTemplate": {
      "parameters": ["dash"],
      "items": [{ "type": "AlexaHeader", "headerTitle": "${dash.title}" }]
    }
  },
  "datasources": {
    "dash": { "title": "Service Health" }
  }
}
```

`token` matters: it identifies this rendered document instance, and it comes back to you in
every subsequent `Alexa.Presentation.APL.UserEvent` from that screen, so your backend knows
which document a touch happened on. (Source:
[Alexa.Presentation.APL Interface Reference](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-interface.html))

## Detect the screen before you send it

Not every device running your skill has a display, and the same interaction model runs on
both. A `RenderDocument` directive sent to a screenless Echo doesn't crash anything, but it's
dead weight, and Amazon's certification checklist for public skills checks that you branch on
interface support rather than assume a screen. Every request carries
`context.System.device.supportedInterfaces`; check for the `Alexa.Presentation.APL` key.

```rust
fn has_display(envelope: &serde_json::Value) -> bool {
    envelope["context"]["System"]["device"]["supportedInterfaces"]
        .get("Alexa.Presentation.APL")
        .is_some()
}

// In the response builder: only push the RenderDocument directive when this is true,
// but always set outputSpeech either way.
if has_display(&envelope) {
    directives.push(render_document_directive);
}
```

Always populate `outputSpeech` regardless of `has_display`. That's not just the fallback for
voice-only Echos, it's also what a blind or low-vision user on a Show relies on, and a display
directive with no speech is a certification finding. `context.Viewport` on every request also
gives the device's real shape and pixel dimensions, backing the responsive design below.

{% hint style="warning" %}
Treat screen detection as a certification gate, not a nice-to-have. A skill that sends
`Alexa.Presentation.APL.RenderDocument` unconditionally will misbehave (silently dropped
directive, or a review rejection) the moment someone runs it on an Echo Dot. Branch on
`supportedInterfaces` every time you build a response, in one shared response-builder
function, not per intent handler.
{% endhint %}

## Viewport profiles: build for the lineup, not one screen

The current Echo Show lineup spans real shape differences: a small Echo Show 5, a mid-size
Echo Show 8, an Echo Show 10 with a motorized swiveling base, and two large fixed displays,
Echo Show 15 (15.6", 1920x1080, the only one that also mounts portrait) and Echo Show 21
(21.4", 1920x1080). Fire TV and Fire tablets running your skill add more shapes again. A
layout hardcoded to one device's pixel dimensions clips or floats awkwardly everywhere else.
(Source, Show 15 and 21 figures: [Device Specifications: Echo Show](https://developer.amazon.com/docs/device-specs/device-specifications-echo-show.html);
Amazon's developer docs do not currently publish equivalent spec pages for Show 5/8/10, so
don't hardcode exact dimensions for those without checking the current retail listing.)

APL's answer is **viewport profiles**, named buckets (`hubLandscapeSmall`,
`hubLandscapeMedium`, `hubLandscapeLarge`, `hubLandscapeXLarge`, `hubPortraitMedium`, plus
round/mobile/TV profiles for other device classes) that group real devices by shape, size, and
orientation rather than exact pixels. Amazon does not publish a device-to-profile mapping
table, so don't assume which profile a given Show maps to, design against the profile
categories, not a specific model. Two mechanisms use them:

- **`when` conditions** on a layout or component, keyed off `@viewportProfileCategory` or the
  profile resource itself, to swap in a different structure per size class rather than
  squeezing one layout everywhere.
- **The `alexa-layouts` import package** (current version 1.7.0), Amazon-maintained
  responsive components that already branch internally per profile, so you often don't write
  `when` conditions yourself at all, see the component library below.

Never size things in raw pixels. Use `dp` (density-independent pixels, APL's analog to CSS
`px` after DPI scaling) for fixed chrome like icon sizes and borders, and `vw`/`vh` (viewport
width/height percentage) for anything that should scale with the actual screen. A metric tile
sized `"width": "200dp"` looks reasonable on a Show 8 and comically small on a Show 21; sized
`"width": "23vw"` it scales with the device. (Source:
[Select the Viewport Profiles Your Skill Supports](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-select-the-viewport-profiles-your-skill-supports.html))

## The responsive component library: reach for these first

Amazon ships a set of prebuilt, already-responsive layouts in the `alexa-layouts` package.
Don't reimplement these; do link the full reference for anything beyond the shape you need.
(Reference: [Responsive Components and Templates](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-layouts-overview.html))

| Component | Use it for |
|---|---|
| `AlexaHeader` | The title bar at the top of nearly every screen. Handles back button, icon, viewport-aware sizing for you. |
| `AlexaTextList` | A scrollable list of text rows, each optionally touchable. Menus, log lines, simple lists. |
| `AlexaDetail` | A "one thing, some facts about it" template (image plus text), in Generic/Movies/Location/Recipe variants. Detail drill-in screens. |
| `AlexaGridList` | A responsive grid of image+text cards with built-in paging. The turnkey choice for a tile dashboard, before you reach for a hand-built `GridSequence`. |

Below those, the layout primitives you compose everything from:

| Primitive | Role |
|---|---|
| `Container` | Flexbox-like box, row or column, your general-purpose layout tool. |
| `Frame` | Gives a group background color, border, corner radius (most components have none on their own). |
| `Sequence` | A scrollable list in one direction, unbounded length. |
| `GridSequence` | A scrollable, fixed-grid repeating layout bound to a data array. Better rendering performance than a `Container` full of children for anything beyond a handful of tiles, and the natural fit for a metric grid you build yourself rather than through `AlexaGridList`. |
| `TouchWrapper` | Wraps any component to make it respond to touch. The only reason a screen becomes a UI instead of a picture. |

Reach for an `Alexa*` responsive template first. Drop to `Container`/`GridSequence`/
`TouchWrapper` when you need a shape Amazon's templates don't offer, a custom dashboard grid
is the common case that pushes you there.

## The interactive loop

This is the mechanism that turns a rendered screen into something a user can act on, and it's
symmetric with voice: a tap and a spoken follow-up both end up as a new request to the same
backend endpoint.

1. Wrap the touchable region in `TouchWrapper` and give it an `onPress` handler containing a
   `SendEvent` command. `SendEvent`'s `arguments` are whatever app-defined values you want back,
   commonly which row of your datasource the user tapped.

```json
{
  "type": "TouchWrapper",
  "id": "metricTile-cpu",
  "onPress": [
    { "type": "SendEvent", "arguments": ["${data.id}", "drillIn"] }
  ],
  "item": {
    "type": "Frame",
    "style": "metricTileFrame",
    "item": { "type": "Text", "text": "${data.label}", "style": "metricValueText" }
  }
}
```

1. That fires an `Alexa.Presentation.APL.UserEvent` request at your backend, the same
   endpoint that handles `IntentRequest`. It carries `request.arguments` (exactly what you
   passed to `SendEvent`), `request.source` (the component's type, handler, and id), and a
   top-level `request.token`, the same document token from the `RenderDocument` that put this
   screen up. Capture the token, you need it to target this document with `ExecuteCommands`.

```rust
#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct AplUserEvent {
    token: String,
    arguments: Vec<serde_json::Value>,
    source: serde_json::Value,
}

fn handle_apl_user_event(request: &serde_json::Value) -> serde_json::Value {
    // Never unwrap or expect in the handler path. A panic returns no response at all,
    // so the user hears Alexa's generic error. See the backend page on error handling.
    let event: AplUserEvent = match serde_json::from_value(request.clone()) {
        Ok(event) => event,
        Err(_) => return render_fallback_speech("Something went wrong with that screen."),
    };
    match event.arguments.as_slice() {
        [metric_id, action] if action == "drillIn" => {
            let metric = metric_id.as_str().unwrap_or_default();
            render_detail_screen(metric, &event.token)
        }
        _ => render_fallback_speech("I didn't catch that."),
    }
}
```

1. Your handler decides what changed and responds with a new directive, either a fresh
   `RenderDocument` for a real screen change, or something cheaper (next section) for a small
   update. No voice re-invocation needed; the loop is entirely tap-driven if you want it to be.

(Sources: [APL TouchWrapper](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-touchwrapper.html),
[SendEvent Command](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-send-event-command.html))

## Cheaper than a full re-render

A whole new `RenderDocument` reloads the document and replaces the visual tree, the right
tool when the screen's *structure* changes (dashboard to detail view). It's the wrong tool for
"update one number." Cheaper, in order of how often you'll reach for them:

- **`ExecuteCommands`**, a directive that runs APL commands (`SetValue`, `AutoPage`, `Scroll`,
  animations) against the document already on screen, no re-send needed. It needs a `token`
  matching the `token` from the `RenderDocument` currently on that screen, a stale or missing
  token means the commands silently don't run, no error surfaced to your logs.
- **`SetValue`**, inside `ExecuteCommands`, changes one component property (text, color,
  visibility) by `id`. The move for "the CPU metric just refreshed."
- **Data-binding expressions**, `${dash.metrics[0].value}` does the "same layout, new
  numbers" work for free just by sending fresh `datasources` against the same document.
  Transformers can reshape or annotate data (text-to-speech markup, image sourcing) before it
  hits the template.

Rule of thumb: component tree unchanged, use `ExecuteCommands`/`SetValue`. Structure changed,
send a new `RenderDocument`.

## Voice drill-in and session state

A user can reach the same handler two ways: tapping a tile, or saying "tell me more about
CPU" while looking at the dashboard. Both must resolve to the same backend logic, and the
voice path needs to know what's on screen to resolve an ambiguous follow-up ("tell me more
about *that*"). That's a session-state problem, not an APL one: track the active document
token and a little "what's displayed" state in session attributes or a backing store, and
have both the `IntentRequest` handler and the `UserEvent` handler read from it. See the
session-attributes discussion in [Interaction model](interaction-model.md).

## Worked example: a metric-grid dashboard

A header plus a responsive grid of touchable metric tiles, the shape most dashboard skills
converge on.

**APL document** (trimmed to the load-bearing parts):

```json
{
  "type": "APL",
  "version": "2024.3",
  "import": [{ "name": "alexa-layouts", "version": "1.7.0" }],
  "styles": {
    "metricTileFrame": {
      "values": [{ "backgroundColor": "#232323", "borderRadius": "8dp" }]
    }
  },
  "mainTemplate": {
    "parameters": ["dash"],
    "items": [
      {
        "type": "Container",
        "width": "100vw",
        "height": "100vh",
        "items": [
          { "type": "AlexaHeader", "headerTitle": "${dash.title}" },
          {
            "type": "GridSequence",
            "grow": 1,
            "scrollDirection": "vertical",
            "childWidth": ["25vw"],
            "childHeight": ["25vh"],
            "data": "${dash.metrics}",
            "items": [
              {
                "type": "TouchWrapper",
                "onPress": [
                  { "type": "SendEvent", "arguments": ["${data.id}", "drillIn"] }
                ],
                "item": {
                  "type": "Frame",
                  "style": "metricTileFrame",
                  "item": {
                    "type": "Container",
                    "alignItems": "center",
                    "items": [
                      { "type": "Text", "text": "${data.value}", "fontSize": "8vh" },
                      { "type": "Text", "text": "${data.label}", "fontSize": "3vh" }
                    ]
                  }
                }
              }
            ]
          }
        ]
      }
    ]
  }
}
```

**Datasource sent alongside it:**

```json
{
  "dash": {
    "title": "Service Health",
    "metrics": [
      { "id": "cpu", "label": "CPU", "value": "42%" },
      { "id": "latency_p99", "label": "P99 Latency", "value": "218ms" },
      { "id": "error_rate", "label": "Error Rate", "value": "0.3%" }
    ]
  }
}
```

**Rust structs that build that datasource:**

```rust
use serde::Serialize;

#[derive(Serialize)]
struct Dashboard { dash: DashPayload }

#[derive(Serialize)]
struct DashPayload { title: String, metrics: Vec<MetricTile> }

#[derive(Serialize)]
struct MetricTile { id: String, label: String, value: String }

fn build_dashboard_datasources(title: &str, metrics: Vec<MetricTile>) -> serde_json::Value {
    let dashboard = Dashboard { dash: DashPayload { title: title.into(), metrics } };
    serde_json::to_value(dashboard).expect("Dashboard always serializes")
}
```

Tapping a tile fires `SendEvent(["cpu", "drillIn"])`, routed by the handler shown earlier to a
detail render for that metric. Everything else on this page, viewport `when` conditions,
`ExecuteCommands` for refreshing just the numbers, applies directly to this document.

## Traps

{% hint style="danger" %}
The roughly 8-second response budget applies to display responses exactly as it does to
voice-only ones. Building the datasource is usually cheap, but if you're calling an LLM or a
slow backend to produce the numbers first, that call is still inside the same clock. See the
latency discussion in [AI integration](ai-integration.md).
{% endhint %}

{% hint style="warning" %}
Total skill response size (speech, directives, session attributes together) is capped at
**120 KB**. A large inline `document` plus a data-heavy `datasources` object can still hit
that; host reusable documents rather than inlining them on every response, and keep
`datasources` to what the current screen actually needs. (Source:
[Request and Response JSON Reference](https://developer.amazon.com/en-US/docs/alexa/custom-skills/request-and-response-json-reference.html))
{% endhint %}

{% hint style="warning" %}
Images referenced in an APL document must be served over HTTPS and are fetched by the device
itself, not by your backend. A private, self-signed, or slow image host means a broken or
delayed tile on screen with no error surfaced to your Lambda logs.
{% endhint %}

{% hint style="info" %}
The developer console's APL authoring tool preview and a real device do not always render
identically, viewport sizing rounding and font fallback are the usual culprits. Treat the
preview as a fast iteration loop, not a final check; test on the real device shapes you care
about (or the simulator's device picker) before calling a layout done.
{% endhint %}

## APL for Audio: a different thing

**APL for Audio (APLA)** is a separate JSON document format for composing layered
text-to-speech, sound effects, and music at runtime, it has nothing to do with the screen.
Don't confuse it with the visual APL covered on this page. See
[APL for Audio Reference](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-for-audio-reference.html)
if you need mixed audio output.

## For Python readers

Everything above maps directly onto `ask-sdk-model`'s
[`RenderDocumentDirective`](https://github.com/alexa/alexa-apis-for-python/blob/master/ask-sdk-model/ask_sdk_model/interfaces/alexa/presentation/apl/render_document_directive.py)
and `ExecuteCommandsDirective` classes, and `ask-sdk-python`'s
[response-building guide](https://developer.amazon.com/en-US/docs/alexa/alexa-skills-kit-sdk-for-python/build-responses.html)
covers attaching them to a handler's response the idiomatic way, construct the directive
object, append it to `response_builder.add_directive(...)`, no manual JSON assembly required.

## Related pages

- [Interaction model](interaction-model.md), voice intents, slots, and the session-state
  mechanics this page's drill-in section depends on.
- [Backend](backend-rust.md), the fulfillment endpoint that receives `UserEvent` requests and
  returns directives.
- [AI integration](ai-integration.md), the latency budget when an LLM sits between a request
  and the datasource you render.
- [Testing and publishing](testing-and-publishing.md), verifying APL renders correctly before
  you ship.

## Sources

- [What's New in APL 2024.3](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-latest-version.html)
- [Alexa.Presentation.APL Interface Reference](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-interface.html)
- [APL Document](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-document.html)
- [APL Data Sources and Transformers](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-data-source-v1.html)
- [APL Package](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-package.html)
- [Select the Viewport Profiles Your Skill Supports](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-select-the-viewport-profiles-your-skill-supports.html)
- [Device Specifications: Echo Show](https://developer.amazon.com/docs/device-specs/device-specifications-echo-show.html)
- [Responsive Components and Templates](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-layouts-overview.html)
- [Grid List (AlexaGridList)](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-alexa-grid-list-layout.html)
- [APL TouchWrapper](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-touchwrapper.html)
- [SendEvent Command](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-send-event-command.html)
- [Request and Response JSON Reference](https://developer.amazon.com/en-US/docs/alexa/custom-skills/request-and-response-json-reference.html)
- [APL for Audio Reference](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-for-audio-reference.html)
- [ask-sdk-model RenderDocumentDirective, GitHub](https://github.com/alexa/alexa-apis-for-python/blob/master/ask-sdk-model/ask_sdk_model/interfaces/alexa/presentation/apl/render_document_directive.py)
- [ask-sdk-python Response Building](https://developer.amazon.com/en-US/docs/alexa/alexa-skills-kit-sdk-for-python/build-responses.html)
