---
description: "Kivy: a Python framework with its own accelerated, touch-oriented widget toolkit."
---

# Kivy

Kivy is a Python UI framework with a custom, OpenGL-backed rendering model and a declarative KV language. Its official introduction documents macOS, Linux, Windows, iOS, and Android targets; it does **not** document a first-party web target. [KivyMD](https://kivymd.readthedocs.io/) is a Material-style widget library for Kivy, not a mechanism that turns Kivy into web deployment.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes | Yes | Yes | Yes | No first-party target |

## Pros

- Excellent fit for touch, animation, canvas work, and a shared mobile/desktop codebase.
- Its own widgets make visual consistency more controllable across operating systems.
- Long-lived project with documented mobile packaging paths.

## Criticisms and trade-offs

- Controls do not automatically look or behave like native platform controls; desktop applications can feel unfamiliar without design work.
- KV language, event properties, rendering, and packaging are a different mental model from conventional Python desktop frameworks.
- Mobile builds rely on platform toolchains; third-party native integrations can raise packaging effort.

## Use it when

Choose Kivy for a custom, touch-first application that must ship to desktop and mobile, and reject it when browser delivery or native desktop widgets are non-negotiable.

**Sources:** [official introduction](https://kivy.org/doc/stable/gettingstarted/intro.html), [packaging guide](https://kivy.org/doc/stable/guide/packaging.html).
