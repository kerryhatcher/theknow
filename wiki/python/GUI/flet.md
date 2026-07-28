---
description: "Flet: Python-first applications delivered through Flutter-based desktop, mobile, and web targets."
---

# Flet

Flet lets Python define a reactive UI over Flutter-based controls. Its documentation describes web, desktop, and mobile applications; the same example can run in a native OS window or with `flet run --web`.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes | Yes | Yes | Yes | Yes |

## Pros

- The broadest explicitly documented delivery matrix in this survey with a single Python-facing UI API.
- Product-oriented controls and responsive layout make it approachable for line-of-business apps.
- Web delivery is a first-class run mode, not an embedded browser workaround.

## Criticisms and trade-offs

- It is a Python layer over a larger Flutter runtime; platform-specific Flutter constraints and package sizes still matter.
- The Python API cannot expose every Flutter/Dart ecosystem capability without extensions.
- Apps have a Flutter-style visual model, not native widgets; evaluate accessibility, startup time, and OS integration in a real build.

## Use it when

Start here when a Python team needs the widest desktop/mobile/web reach and can accept Flutter-rendered controls. Validate release packaging and mobile-device workflows before selecting it for a regulated or deeply native product.

**Sources:** [Flet introduction](https://flet.dev/docs/), [publishing guide](https://flet.dev/docs/publish/), [GitHub project](https://github.com/flet-dev/flet).
