---
description: "Reflex: a full-stack web application framework written in Python and compiled to browser UI."
---

# Reflex

Reflex (formerly Pynecone) is a Python-first full-stack web framework. It compiles declarative components to JavaScript/React for the browser while Python manages state and backend behavior. It is therefore web delivery, not native desktop/mobile GUI delivery.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Browser | Browser | Browser | Browser | Browser | Yes |

## Pros

- One Python codebase for UI, server-side state, routing, and backend concerns.
- Uses browser capabilities and can wrap React components when built-in components are insufficient.
- Good conceptual fit for multi-page data and product web applications.

## Criticisms and trade-offs

- The compiled React/frontend pipeline is real complexity even though app code is Python; debugging may cross language boundaries.
- Server-mediated state can affect latency, hosting cost, and scaling architecture.
- Browser reach should not be counted as native mobile or desktop support.

## Use it when

Use Reflex when the deliverable is a full-stack web application and a Python-only authoring surface is valuable. Do not select it for offline-first native applications.

**Sources:** [Reflex introduction](https://reflex.dev/docs/getting-started/introduction/), [how Reflex works](https://reflex.dev/docs/advanced-onboarding/how-reflex-works/), [project repository](https://github.com/reflex-dev/reflex).
