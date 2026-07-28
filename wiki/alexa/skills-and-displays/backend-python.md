---
description: Build an Alexa custom-skill backend in Python with the official ASK SDK, AWS Lambda, APL, persistence, and a production deployment checklist.
---

# The fulfillment backend in Python

For a new custom Alexa skill, use **Python with Amazon's ASK SDK for Python** and host it in
your own AWS Lambda. This is the lowest-friction supported route: the SDK models Alexa requests,
dispatches them to handlers, builds valid responses, and has DynamoDB persistence and web-service
adapters. Lambda avoids public-webhook TLS and signature-verification work.

{% hint style="info" %}
This page assumes a custom skill with optional Echo Show UI. Alexa-hosted Python is suitable for a
quick prototype, but a Lambda in your AWS account is the better default when you need current
runtimes, IAM control, logs, alarms, private networking, or external data and AI services.
{% endhint %}

## The choices to make before writing code

| Decision | Default | Change it only when |
|---|---|---|
| Endpoint | AWS Lambda ARN | The logic already belongs in an always-on HTTPS service. |
| SDK | `ask-sdk` | Never for a normal Python skill; it packages the core SDK, models, and DynamoDB adapter. |
| Handler style | Handler classes | A tiny skill is clearer with decorators. Pick one style and stay consistent. |
| State | `session_attributes` for the active conversation; DynamoDB for durable state | You have no state to retain, or another durable store is already authoritative. |
| Display | Add APL only behind an interface check | The skill is explicitly voice-only. |

Start with a currently supported Python runtime shown in the Lambda console, not an old runtime
number in a sample. The ASK SDK documentation requires Python 3.8 or later, but Lambda runtime
support changes independently; use a runtime AWS currently supports and schedule upgrades before
deprecation.

## Create the smallest deployable backend

Create a virtual environment, then install the SDK:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install ask-sdk
python -m pip freeze > requirements.txt
```

`ask-sdk` is the convenient full distribution. If package size matters, start with
`ask-sdk-core` and add only the packages you use; add
`ask-sdk-dynamodb-persistence-adapter` when you need durable skill attributes.

The following `lambda_handler.py` is a complete first slice: launch, one custom intent, required
help/stop handling, an exception handler, and a conditional APL response. The Lambda handler
setting is `lambda_handler.handler`.

```python
import json
from pathlib import Path

import ask_sdk_core.utils as ask_utils
from ask_sdk_core.dispatch_components import AbstractExceptionHandler, AbstractRequestHandler
from ask_sdk_core.skill_builder import SkillBuilder
from ask_sdk_model.interfaces.alexa.presentation.apl import RenderDocumentDirective


def supports_apl(handler_input) -> bool:
    interfaces = ask_utils.get_supported_interfaces(handler_input)
    return "Alexa.Presentation.APL" in interfaces


APL_DOCUMENT = json.loads(
    (Path(__file__).parent / "apl" / "status.json").read_text(encoding="utf-8")
)


class LaunchRequestHandler(AbstractRequestHandler):
    def can_handle(self, handler_input):
        return ask_utils.is_request_type("LaunchRequest")(handler_input)

    def handle(self, handler_input):
        speech = "Welcome. Say show status."
        return handler_input.response_builder.speak(speech).ask(speech).response


class ShowStatusIntentHandler(AbstractRequestHandler):
    def can_handle(self, handler_input):
        return ask_utils.is_intent_name("ShowStatusIntent")(handler_input)

    def handle(self, handler_input):
        speech = "The system status is okay."
        builder = handler_input.response_builder.speak(speech).ask("What would you like next?")

        if supports_apl(handler_input):
            builder.add_directive(
                RenderDocumentDirective(
                    token="status-v1",
                    document=APL_DOCUMENT,
                    datasources={"status": {"title": "System status", "value": "OK"}},
                )
            )
        return builder.response


class HelpIntentHandler(AbstractRequestHandler):
    def can_handle(self, handler_input):
        return ask_utils.is_intent_name("AMAZON.HelpIntent")(handler_input)

    def handle(self, handler_input):
        return handler_input.response_builder.speak(
            "You can say show status."
        ).ask("Try saying show status.").response


class CancelOrStopIntentHandler(AbstractRequestHandler):
    def can_handle(self, handler_input):
        return ask_utils.is_intent_name("AMAZON.CancelIntent")(handler_input) or \
            ask_utils.is_intent_name("AMAZON.StopIntent")(handler_input)

    def handle(self, handler_input):
        return handler_input.response_builder.speak("Goodbye.").response


class FallbackIntentHandler(AbstractRequestHandler):
    def can_handle(self, handler_input):
        return ask_utils.is_intent_name("AMAZON.FallbackIntent")(handler_input)

    def handle(self, handler_input):
        return handler_input.response_builder.speak(
            "Sorry, I don't know that one. You can say show status."
        ).ask("Try saying show status.").response


class SessionEndedRequestHandler(AbstractRequestHandler):
    def can_handle(self, handler_input):
        return ask_utils.is_request_type("SessionEndedRequest")(handler_input)

    def handle(self, handler_input):
        # Do cleanup only. Alexa ignores speech and directives for this request.
        return handler_input.response_builder.response


class CatchAllExceptionHandler(AbstractExceptionHandler):
    def can_handle(self, handler_input, exception):
        return True

    def handle(self, handler_input, exception):
        # Log the exception with your normal structured logger; never expose it to the user.
        return handler_input.response_builder.speak(
            "Sorry, I had trouble doing that. Please try again."
        ).ask("Please try again.").response


sb = SkillBuilder()
sb.add_request_handler(LaunchRequestHandler())
sb.add_request_handler(ShowStatusIntentHandler())
sb.add_request_handler(HelpIntentHandler())
sb.add_request_handler(CancelOrStopIntentHandler())
sb.add_request_handler(FallbackIntentHandler())
sb.add_request_handler(SessionEndedRequestHandler())
sb.add_exception_handler(CatchAllExceptionHandler())

handler = sb.lambda_handler()
```

The `can_handle` predicates are checked in registration order. Put narrowly scoped handlers
before broad handlers and keep a fallback near the end. `LaunchRequest`, `IntentRequest`,
`SessionEndedRequest`, and `Alexa.Presentation.APL.UserEvent` are distinct request types; the
SDK gives you the envelope, but it cannot choose your conversation behavior for you.

## Keep the display path conditional

`Alexa.Presentation.APL` is absent from `supportedInterfaces` on a screenless Echo. Always
produce speech; add `RenderDocument` only when `supports_apl()` returns true. The directive's
`token` identifies that presentation—use a stable, meaningful value and check it before sending
later `ExecuteCommands` to an existing display.

Keep APL JSON under version control alongside the code, for example:

```text
lambda/
  lambda_handler.py
  apl/
    status.json
  requirements.txt
```

The Python model object used above serializes the directive correctly. Do not construct response
JSON strings by hand. See [Screen UI with APL](apl-displays.md) for `UserEvent`, datasources,
viewport design, and touch handling.

## Handle touch and session state deliberately

`TouchWrapper` can emit `Alexa.Presentation.APL.UserEvent`. Handle it as a request type and treat
`request.arguments` as untrusted input: use a small action vocabulary you own, validate argument
count and types, then map it to application logic. Do not let a client-side event name select a
Python function or data query directly.

```python
class AplUserEventHandler(AbstractRequestHandler):
    def can_handle(self, handler_input):
        return ask_utils.is_request_type(
            "Alexa.Presentation.APL.UserEvent"
        )(handler_input)

    def handle(self, handler_input):
        arguments = handler_input.request_envelope.request.arguments or []
        action = arguments[0] if arguments else None
        if action == "refresh":
            return handler_input.response_builder.speak("Refreshing the status.").response
        return handler_input.response_builder.speak("I couldn't use that control.").response
```

Register this handler before any generic request handler. For a multi-turn conversation, write
small JSON-serializable values to `handler_input.attributes_manager.session_attributes`; they
vanish when the session ends. For preferences, accounts, cached data, or a workflow that must
survive the next invocation, use a durable store. The ASK SDK provides a DynamoDB persistence
adapter; assign it to the skill builder and use `persistent_attributes`, saving only when a
meaningful state change occurs.

```python
from ask_sdk_dynamodb.adapter import DynamoDbAdapter

sb = SkillBuilder(
    persistence_adapter=DynamoDbAdapter(table_name="my-skill-state", create_table=False)
)

# In a handler:
attributes = handler_input.attributes_manager.persistent_attributes
attributes["units"] = "metric"
handler_input.attributes_manager.save_persistent_attributes()
```

Give the Lambda execution role least-privilege access to that exact table. Do not use the Alexa
user ID as an authentication token or expose it in speech, logs, or a display; it is an opaque
identifier suitable as a storage key only after you decide on retention and deletion behavior.

## Secure the Lambda invocation

In Lambda, add an **Alexa Skills Kit** trigger, enable **Skill ID verification**, and enter the
Skill ID from the Developer Console. This puts the restriction in Lambda's resource policy:
requests from another skill do not invoke the function at all. It is stronger and simpler than an
in-handler application-ID check.

Then paste the Lambda ARN into **Build → Endpoint** in the Alexa Developer Console. Verify all
three facts before debugging code: the ARN matches the deployed function or alias, the Alexa
trigger exists, and the trigger's Skill ID matches the skill. A correct handler with a missing
trigger appears as a skill that simply never responds.

Use an HTTPS endpoint only when you truly need an existing service. In that mode, use the ASK
SDK's web-service support or Flask/Django adapter and retain the raw request-validation middleware.
You must validate Alexa's certificate-chain URL and request signature and reject stale requests;
do not approximate this with an IP allowlist or a shared secret.

## Package and deploy

For a zip deployment, Lambda needs application code and dependencies at the root of the archive.
A repeatable packaging shape is:

```bash
rm -rf build
mkdir build
python -m pip install --requirement requirements.txt --target build
cp lambda_handler.py build/
cp -R apl build/
(cd build && zip -r ../skill.zip .)
```

`rm -rf build` is safe only when `build` is the dedicated, verified package directory in the
repository. A deployment framework such as SAM, CDK, or Terraform is preferable once the skill
has more than one environment, because it version-controls the role, trigger permission, runtime,
memory, timeout, environment variables, log retention, and alarms as infrastructure.

Pure-Python wheels can be installed on any build platform. If a dependency has compiled code,
build it for Lambda's Linux environment and selected architecture, or use a compatible container
build; a macOS or Windows native wheel may import locally and fail in Lambda. Keep dependencies
and the runtime's `boto3` versions intentional—AWS recommends packaging the SDK dependencies you
use rather than relying on the version included in the runtime.

Set a Lambda timeout below Alexa's end-to-end response limit so the function fails while there is
still time to return a useful fallback. For external HTTP or Bedrock calls, use a client timeout
shorter than the Lambda timeout, catch it, and respond with a brief retry prompt. Do not send the
work to a background thread and hope Alexa waits: the invocation response is still bounded.

## Production checklist

- [ ] Current supported Lambda Python runtime, pinned dependencies, and reproducible package build.
- [ ] Alexa Skills Kit trigger with Skill ID verification and a least-privilege execution role.
- [ ] `AMAZON.HelpIntent`, `AMAZON.StopIntent`, `AMAZON.CancelIntent`, and `AMAZON.FallbackIntent` handlers.
- [ ] Speech on every display path; APL only after `supportedInterfaces` detection.
- [ ] Session state separated from durable state; durable data has retention/deletion design.
- [ ] External calls have explicit connect/read timeouts, error handling, and a latency fallback.
- [ ] Structured logs with request IDs but no access tokens, raw user data, or secrets.
- [ ] Unit tests for handler routing and response directives, console tests for NLU, and real Echo
  Show plus screenless-device tests before certification.

## Sources

- [Setting Up the ASK SDK](https://developer.amazon.com/en-US/docs/alexa/alexa-skills-kit-sdk-for-python/set-up-the-sdk.html), Amazon developer documentation
- [Developing Your First Skill](https://developer.amazon.com/en-US/docs/alexa/alexa-skills-kit-sdk-for-python/develop-your-first-skill.html), Amazon developer documentation
- [Host a Custom Skill as an AWS Lambda Function](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-an-aws-lambda-function.html), Amazon developer documentation
- [Host a Custom Skill as a Web Service](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-a-web-service.html), Amazon developer documentation
- [Add APL Support to Your Skill Code](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/use-apl-with-ask-sdk.html), Amazon developer documentation
- [Working with .zip file archives for Python Lambda functions](https://docs.aws.amazon.com/lambda/latest/dg/python-package.html), AWS Lambda documentation
