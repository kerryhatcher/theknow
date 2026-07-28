---
description: How an utterance becomes a typed request your backend can switch on, covering invocation names, intents, slots, entity resolution, dialog management, and session state.
---

# The interaction model

The interaction model is the JSON document that tells Alexa's NLU what a user can say and how
to turn that speech into a structured request your code receives. Everything the user *says*
is downstream of this: no intent match, no `IntentRequest`, nothing to render in response to
speech. A tap on an already-rendered screen is a separate path, an APL user event request
reaches your endpoint directly, without ASR or NLU involved at all, see
[APL and displays](apl-displays.md) for that loop. This page covers the voice half of the
contract; the request and response envelope your Lambda actually handles lives in
[The fulfillment backend in Rust](backend-rust.md).

## The mental model

A user says something to a device. Alexa's cloud service does two jobs before your code ever
runs: automatic speech recognition (ASR) turns audio into text, and natural language
understanding (NLU) matches that text against your interaction model to pick an intent and
extract slot values. What lands on your endpoint is already a parsed `IntentRequest` with
`intent.name` and a `slots` map, not raw text. You never see the transcript unless you ask for
it explicitly through the (separate) transcription features.

Two invocation shapes matter for how you write utterances:

- **One-shot**, the user says the invocation name and the request in a single utterance:
  "Alexa, ask trail status for Bear Creek." No back-and-forth, the intent and slots resolve
  immediately.
- **Session-based**, the user opens the skill first ("Alexa, open trail status"), gets a
  `LaunchRequest`, and then speaks follow-up utterances inside the open session without
  repeating the invocation name.

Design your sample utterances for both. If every utterance you write assumes the invocation
name is already said ("what's the status" instead of "ask trail status what's the status"),
one-shot users get a fallback instead of a match, because the one-shot phrase is the
invocation name plus the utterance concatenated, not the utterance alone.

## Invocation name rules that actually bite

The full constraint list is long and mostly self-evident (lowercase, spell out numbers, no
profanity). The ones that fail certification or quietly kill matching, worth checking before
you settle on a name:

- **No single-word names**, unless you can prove IP ownership of that word. "Weatherbot" fails,
  "Acme Weatherbot" or "ask Acme" passes.
- **Can't contain a person's or place's name alone.** "Molly" is rejected; "Molly's horoscope"
  is fine.
- **Can't include the wake words** "Alexa," "Amazon," or "Echo," and can't include "skill" or
  "app."
- **Can't include a launch phrase** like "ask," "open," "launch," "tell," or "start" as part of
  the name itself, those are the carrier words users say around the invocation name, not part
  of it.
- **No two-word name where one word is an article or preposition** ("the trail," "at home").

{% hint style="warning" %}
Certification rejects on IP infringement and on names Amazon judges "too generic to be
distinctive," which is a judgment call, not a mechanical rule. If your working name is a
single common noun or a category term ("recipes," "weather"), expect a bounce and budget time
for a rename.
{% endhint %}

Source: [Choose the Invocation Name for a Custom Skill](https://developer.amazon.com/en-US/docs/alexa/custom-skills/choose-the-invocation-name-for-a-custom-skill.html).

## Intents: custom and the built-ins you can't skip

An intent is a named action, "the thing the user wants to happen." You define custom intents
(`GetTrailStatusIntent`, `SetDestinationIntent`) with their own sample utterances and slots.
Alexa sends lifecycle request types such as `LaunchRequest` and `SessionEndedRequest` when they
occur. Built-in intents are different: include an intent in the interaction model before Alexa
sends it to your service (except for interface-specific cases such as AudioPlayer controls).
For a custom skill, `AMAZON.StopIntent` is required; Help, Cancel, and Fallback are strongly
recommended when they fit the experience and must be handled if you include them.

| Type | When it fires | If you skip it |
|---|---|---|
| `LaunchRequest` | User opens the skill with no specific ask ("Alexa, open trail status") | No welcome response; users who invoke the plain skill name get a dead end |
| `AMAZON.HelpIntent` | User asks for help, if included in the model | Give contextual help; recommended for a usable voice experience |
| `AMAZON.StopIntent` | User says "stop" | Certification failure; the tester says "stop" and expects a clean, non-erroring response |
| `AMAZON.CancelIntent` | User says "cancel" or "never mind," if included in the model | Usually exit or cancel the current task cleanly |
| `AMAZON.FallbackIntent` | Speech doesn't match any of your intents well enough, if included in the model | Give one place to handle out-of-domain utterances |
| `SessionEndedRequest` | Session is closing (timeout, error, or user exit) for a reason other than your own `shouldEndSession: true` | Nothing you do here reaches the user (no speech, no directives are honored), but skipping the handler means you miss the chance to log why the session died |

Quick-start templates can include common built-ins, but do not assume a new interaction model
automatically adds them. Leaving an intent in the model isn't enough: your Lambda handler still
has to return a sensible response for every intent you include. A generic fallback response is
fine; an unhandled-match error is not.

Amazon's own documentation is inconsistent about `AMAZON.NavigateHomeIntent`. The
[Standard Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/custom-skills/standard-built-in-intents.html)
reference does not list it as a must-implement intent, but the
[Tips for Using Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/interaction-model-design/tips-for-using-built-in-intents-for-your-skill.html)
page calls it required outright for any skill with a multimodal (visual, on-screen) component.
In practice Alexa handles `NavigateHomeIntent` on-device for screen-capable skills, so your
Lambda usually never sees it and needs no handler. Declaring it in a multimodal interaction
model costs nothing either way, so declare it and move on rather than betting on which Amazon
page is current.

Source: [Standard Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/custom-skills/standard-built-in-intents.html),
[Implement the Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/custom-skills/implement-the-built-in-intents.html),
[Functional Testing for a Custom Skill](https://developer.amazon.com/en-US/docs/alexa/custom-skills/functional-testing-for-a-custom-skill.html),
[Tips for Using Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/interaction-model-design/tips-for-using-built-in-intents-for-your-skill.html).

## Slots: built-in types, custom types, and entity resolution

A slot is a named variable inside an intent's utterance: "show me the {Metric} dashboard."
Slot types come in two flavors.

- **Built-in types** (`AMAZON.DATE`, `AMAZON.NUMBER`, `AMAZON.City`, dozens more) are
  Amazon-maintained and already understand the ways people say a date or a number.
- **Custom types** are your own enumerated list of values, each with optional synonyms:
  `{"value": "Bear Creek", "synonyms": ["bear trail", "the bear one"]}`.

{% hint style="danger" %}
**A custom slot type is a hint to the NLU, not an enforced enum.** Defining `TrailName` with
three values does not mean only those three values can ever land in the slot. The NLU uses
your list to bias recognition toward those values and their phonetic neighbors, but it will
still fill the slot with whatever it heard if nothing close matches. Code that does
`match slot.value.as_str() { "Bear Creek" => ..., "Meadow Loop" => ..., _ => unreachable!() }`
will panic in production the first time someone says a trail name you didn't list. Always
handle the unmatched case, and check entity resolution status, not just the raw slot value.
{% endhint %}

That's what entity resolution is for. Alongside the raw spoken text, a resolved slot carries a
`resolutions.resolutionsPerAuthority` array with a status code per slot type you defined:

- **`ER_SUCCESS_MATCH`**, the spoken value matched a value or synonym you defined (or, for an
  extended built-in type, an entry in Alexa's own knowledge graph). You get back the canonical
  value and its ID in `values[0]`, not just whatever the user said, so "the bear one" and "Bear
  Creek" both resolve to the same ID. A match can carry more than one candidate: an ambiguous
  spoken term (a name that's close to two of your defined values) returns multiple entries in
  `values` under the same `ER_SUCCESS_MATCH` status, so don't just grab `values[0]` blindly,
  check the length first and reprompt to disambiguate ("did you mean X or Y") when there's more
  than one.
- **`ER_SUCCESS_NO_MATCH`**, nothing you defined matched. The raw slot value is still there,
  it's just unresolved.
- **`ER_ERROR_TIMEOUT`** and **`ER_ERROR_EXCEPTION`**, the resolution process itself failed.
  These are not a no-match, they're a resolver failure, and a handler that treats every
  non-success status as "user said something outside my list" will silently swallow a real
  backend problem. Log these separately and fall back to the raw slot text rather than treating
  them the same as `ER_SUCCESS_NO_MATCH`.

Branch on the full status set above, not on a binary match/no-match and not on the raw string.
A no-match isn't an error, it's the normal path for "the value is outside what I anticipated,"
and your handler should reprompt or fall back to the raw text rather than assume every slot
fill is one of your enumerated values or that every non-match status means the same thing.

Sources: [Entity Resolution](https://developer.amazon.com/en-US/docs/alexa/custom-skills/entity-resolution.html),
[Entity Resolution for Custom Slot Types](https://developer.amazon.com/en-US/docs/alexa/custom-skills/entity-resolution-for-custom-slot-types.html).

## Sample utterances: how many, how varied

There's no hard minimum the console enforces, but certification reviewers and the NLU model
both reward variety over volume. Practical guidance that holds up:

- **Cover the phrasings a real person would use**, not just the one that reads cleanly in a
  spec. "What's the trail status," "how's Bear Creek looking," "is Bear Creek open" are three
  utterances for one intent, not three intents.
- **Don't write slot-only utterances** like `"{TrailName}"` on its own. A bare slot with
  nothing else is nearly impossible for the NLU to disambiguate from noise or from a different
  intent's slot, and it's a common certification-review flag.
- **Don't let two intents share near-identical utterances.** If `GetStatusIntent` and
  `SetDestinationIntent` both have a sample like "{TrailName}", the NLU has to guess between
  them on every request, and it will guess wrong some fraction of the time. Keep the carrier
  phrase (the words around the slot) distinct per intent: "how's {TrailName} looking" versus
  "take me to {TrailName}."
- **Carrier phrases matter more than slot coverage.** You don't need every trail name as a
  literal sample, the slot type handles that. You need enough distinct sentence shapes around
  the slot that the NLU learns your intent's pattern, not one specific value.

Good:

```json
{
  "name": "GetTrailStatusIntent",
  "slots": [{ "name": "TrailName", "type": "TRAIL_NAME" }],
  "samples": [
    "what's the status of {TrailName}",
    "how's {TrailName} looking",
    "is {TrailName} open",
    "check {TrailName}"
  ]
}
```

Bad, same intent: `"samples": ["{TrailName}", "status", "trail"]`. `"{TrailName}"` alone
collides with any other intent that also takes a bare slot, and `"status"`/`"trail"` carry no
slot at all, they're really testing whether the user meant this intent versus
`AMAZON.FallbackIntent` with no signal to go on.

## Dialog management: when the model collects slots for you

For a multi-slot intent, you can let Alexa's Dialog interface run the back-and-forth instead
of writing that state machine yourself. Each incoming `IntentRequest` carries a `dialogState`:
`STARTED`, `IN_PROGRESS`, or `COMPLETED`. Two ways to drive it:

- **`Dialog.Delegate`**, return this directive and Alexa fully owns collecting every slot
  marked `elicitationRequired`, prompting with the prompts you configured in the model, and
  only calls your handler again once `dialogState` is `COMPLETED`. Least code, least control.
- **Manual elicitation with `Dialog.ElicitSlot`**, you get an `IntentRequest` on every turn
  (`dialogState: IN_PROGRESS`) and decide yourself what to ask for next, useful when a later
  slot depends on an earlier answer (don't ask for "roast" until "drink" is "coffee").

Slot validation rules (`confirmationRequired`, and `validations` for range/pattern checks)
live in the model alongside the elicitation prompts, so "reject a negative quantity" or
"confirm before booking" doesn't need a code path at all if the built-in dialog handles it.
The model's `dialog.intents[].delegationStrategy` is what switches between the two: `ALWAYS`
makes the console emit `Dialog.Delegate` for you, `SKILL_RESPONSE` hands control back to your
handler on every turn. The full worked example below shows the shape.

Sources: [Dialog Interface Reference](https://developer.amazon.com/en-US/docs/alexa/custom-skills/dialog-interface-reference.html),
[Delegate Dialog to Alexa](https://developer.amazon.com/en-US/docs/alexa/custom-skills/delegate-dialog-to-alexa.html).

## Session state: sessionAttributes, and why it isn't storage

`sessionAttributes` is a key-value map you return in your response; Alexa echoes it back on
the next request in the same session. It's the right place for "what did the user just say"
across a single back-and-forth, not for anything that needs to survive past the session.

The session ends when: you return `shouldEndSession: true`, the user says something that
doesn't match your model and there's no reprompt left, or the microphone times out waiting for
a response with nothing said. The moment it ends, `sessionAttributes` is gone. If your skill
needs to remember something across sessions (a user's saved preference, "what was on screen
last time they looked"), that has to live in external storage keyed by `context.System.user.userId`,
DynamoDB is the standard choice and `ask-sdk-dynamodb-persistence-adapter` wraps it for you on
the Node/Python/Java SDKs. This matters directly for the display side: "what's currently
rendered on the Echo Show" is state your backend owns, not something Alexa tracks for you
between requests, see [APL and displays](apl-displays.md) for the render/update loop that
depends on it.

Source: [Manage Skill Session and Session Attributes](https://developer.amazon.com/en-US/docs/alexa/custom-skills/manage-skill-session-and-session-attributes.html).

## Worked example: model plus dispatch

A trimmed interaction model, one custom intent with two slots, dialog enabled, plus the
built-ins:

```json
{
  "interactionModel": {
    "languageModel": {
      "invocationName": "trail status",
      "intents": [
        { "name": "AMAZON.HelpIntent", "samples": [] },
        { "name": "AMAZON.CancelIntent", "samples": [] },
        { "name": "AMAZON.StopIntent", "samples": [] },
        { "name": "AMAZON.FallbackIntent", "samples": [] },
        {
          "name": "GetTrailStatusIntent",
          "slots": [
            { "name": "TrailName", "type": "TRAIL_NAME" },
            { "name": "VisitDate", "type": "AMAZON.DATE" }
          ],
          "samples": [
            "what's the status of {TrailName}",
            "how's {TrailName} looking on {VisitDate}",
            "is {TrailName} open"
          ]
        }
      ],
      "types": [
        {
          "name": "TRAIL_NAME",
          "values": [
            { "id": "bear_creek", "name": { "value": "Bear Creek", "synonyms": ["the bear one"] } },
            { "id": "meadow_loop", "name": { "value": "Meadow Loop", "synonyms": ["meadow trail"] } }
          ]
        }
      ]
    },
    "dialog": {
      "intents": [
        {
          "name": "GetTrailStatusIntent",
          "delegationStrategy": "ALWAYS",
          "slots": [
            {
              "name": "TrailName",
              "type": "TRAIL_NAME",
              "elicitationRequired": true,
              "confirmationRequired": false,
              "prompts": { "elicitation": "Elicit.Slot.GetTrailStatusIntent.TrailName" }
            }
          ]
        }
      ]
    },
    "prompts": [
      {
        "id": "Elicit.Slot.GetTrailStatusIntent.TrailName",
        "variations": [
          { "type": "PlainText", "value": "Which trail do you want the status for?" }
        ]
      }
    ]
  }
}
```

`elicitationRequired: true` only does something if the slot's `prompts.elicitation` points at
an entry in this top-level `prompts` array; without both pieces `ask deploy` rejects the model.
The developer console fills this in for you when you set elicitation through the UI, a
hand-written skill package needs to write it out explicitly, as above. See the
[Interaction Model Schema](https://developer.amazon.com/en-US/docs/alexa/smapi/interaction-model-schema.html)
for the full `prompts` entry shape.

And the matching dispatch shape on the Rust side, request type first, then intent name. This is
the same `match` shown in full in [The fulfillment backend in Rust](backend-rust.md); here's
just the routing skeleton, including the APL user event arm a display skill needs alongside the
voice arms:

```rust
let response_body = match request_type {
    "LaunchRequest" => launch_response(),
    "IntentRequest" => {
        let intent_name = envelope["request"]["intent"]["name"].as_str().unwrap_or_default();
        match intent_name {
            "GetTrailStatusIntent" => get_trail_status(&envelope),
            "AMAZON.HelpIntent" => help_response(),
            "AMAZON.StopIntent" | "AMAZON.CancelIntent" => end_response("Goodbye!"),
            "AMAZON.FallbackIntent" => end_response("I didn't catch that. Try asking about a trail."),
            _ => end_response("Sorry, I didn't understand that."),
        }
    }
    "Alexa.Presentation.APL.UserEvent" => handle_user_event(&envelope),
    "SessionEndedRequest" => json!({ "response": {} }),
    _ => end_response("Unsupported request type."),
};
```

`handle_user_event` never goes through this page's model at all, a button tap arrives as this
request type directly, with no ASR and no intent match. See
[APL and displays](apl-displays.md) for what the handler does with it.

`get_trail_status` is where you'd read `intent.slots.TrailName.resolutions` and branch on
`ER_SUCCESS_MATCH` versus `ER_SUCCESS_NO_MATCH` per the entity resolution section above,
rather than trusting the raw slot string.

Python readers: the same routing pattern in `ask-sdk-python` is a chain of
`AbstractRequestHandler` subclasses, each with a `can_handle(handler_input)` and
`handle(handler_input)` method, registered onto a `SkillBuilder`. See
[Request Processing](https://developer.amazon.com/en-US/docs/alexa/alexa-skills-kit-sdk-for-python/handle-requests.html)
and the [SDK core API reference](https://alexa-skills-kit-python-sdk.readthedocs.io/en/latest/api/core.html).

## Locale: one model per language, not one model total

The interaction model is defined per locale (`en-US`, `en-GB`, `de-DE`, and so on). Intents,
slots, sample utterances, and slot type values are all locale-specific; a skill supporting
`en-US` and `en-GB` maintains two versions of the language model side by side in the same
skill, sharing configuration that isn't language-dependent (interfaces, the endpoint,
account linking). If you're scoping a new project for a single market, build one locale, but
don't structure your intent names or slot IDs in a way that assumes there will only ever be
one, adding a locale later is additive, not a rewrite, as long as your backend keys off intent
and slot names rather than the literal utterance text. See
[Develop Skills in Multiple Languages](https://developer.amazon.com/en-US/docs/alexa/custom-skills/develop-skills-in-multiple-languages.html).

## Alexa+ and generative-skill tooling: does this still apply in 2026?

Yes, for a classic custom skill. Amazon's Alexa+ push (announced February 2025) added three
new "AI-native" SDKs, Action, Web Action, and Multi-Agent, aimed at letting Alexa+ call your
API or navigate your website directly through LLM-driven reasoning, bypassing the intent/slot
model entirely for that use case. Amazon has stated plainly that classic skills "will remain
available to customers using the original Alexa experience," and developers "can continue to
update, certify, publish, and create new skills on original Alexa," while new tooling
investment shifts toward the Alexa+ SDKs. For a display skill built in 2026, the interaction
model described here is still the current, supported path; treat the Alexa+ SDKs as a
separate, moving target and re-check their state before betting a new project on them
(unverified beyond the February 2025 announcement as of 2026-07).

Source: [Introducing AI-native SDKs for Alexa+](https://developer.amazon.com/en-US/blogs/alexa/alexa-skills-kit/2025/02/new-alexa-announce-blog).

## Related pages

- [Skill setup and tooling](skill-setup-and-tooling.md), console, ASK CLI, and where the
  interaction model actually gets edited and deployed.
- [APL and displays](apl-displays.md), what happens after an intent resolves and you need to
  put something on the Echo Show's screen.
- [The fulfillment backend in Rust](backend-rust.md), the full request/response JSON envelope
  and the Rust types for it.

## Sources

- [Choose the Invocation Name for a Custom Skill](https://developer.amazon.com/en-US/docs/alexa/custom-skills/choose-the-invocation-name-for-a-custom-skill.html)
- [Standard Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/custom-skills/standard-built-in-intents.html)
- [Implement the Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/custom-skills/implement-the-built-in-intents.html)
- [Tips for Using Built-in Intents](https://developer.amazon.com/en-US/docs/alexa/interaction-model-design/tips-for-using-built-in-intents-for-your-skill.html)
- [Functional Testing for a Custom Skill](https://developer.amazon.com/en-US/docs/alexa/custom-skills/functional-testing-for-a-custom-skill.html)
- [Entity Resolution](https://developer.amazon.com/en-US/docs/alexa/custom-skills/entity-resolution.html)
- [Entity Resolution for Custom Slot Types](https://developer.amazon.com/en-US/docs/alexa/custom-skills/entity-resolution-for-custom-slot-types.html)
- [Dialog Interface Reference](https://developer.amazon.com/en-US/docs/alexa/custom-skills/dialog-interface-reference.html)
- [Delegate Dialog to Alexa](https://developer.amazon.com/en-US/docs/alexa/custom-skills/delegate-dialog-to-alexa.html)
- [Interaction Model Schema](https://developer.amazon.com/en-US/docs/alexa/smapi/interaction-model-schema.html)
- [Manage Skill Session and Session Attributes](https://developer.amazon.com/en-US/docs/alexa/custom-skills/manage-skill-session-and-session-attributes.html)
- [Develop Skills in Multiple Languages](https://developer.amazon.com/en-US/docs/alexa/custom-skills/develop-skills-in-multiple-languages.html)
- [Introducing AI-native SDKs for Alexa+](https://developer.amazon.com/en-US/blogs/alexa/alexa-skills-kit/2025/02/new-alexa-announce-blog)
- [Request Processing, ask-sdk-python](https://developer.amazon.com/en-US/docs/alexa/alexa-skills-kit-sdk-for-python/handle-requests.html)
- [ask-sdk-python core API reference](https://alexa-skills-kit-python-sdk.readthedocs.io/en/latest/api/core.html)
