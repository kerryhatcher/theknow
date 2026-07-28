---
description: "BeeWare and Toga: Python-native application tooling and native widgets across desktop and mobile."
---

# BeeWare and Toga

BeeWare is an ecosystem; **Toga** is its cross-platform GUI toolkit and **Briefcase** packages applications. Toga maps a Python API to platform-native widgets where possible. Its documented targets include macOS, Windows, Linux, iOS, Android, and web support that should be treated as an evolving target rather than equivalent to desktop/mobile releases.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes | Yes | Yes | Yes | Evolving/validate |

## Pros

- A Python-first route to native application packages and native-looking controls.
- Briefcase makes the packaging story part of the ecosystem rather than an unrelated afterthought.
- Attractive for teams that value platform conventions over pixel-identical rendering.

## Criticisms and trade-offs

- The widget set, integrations, and community examples are smaller than Qt's; expect to validate advanced controls early.
- Platform support is not uniform: each backend has its own maturity and capability limits.
- “One codebase” does not eliminate app-signing, SDK, store, or platform-specific debugging work.

## Use it when

Choose it for Python-native mobile and desktop apps that benefit from native widgets. Avoid assuming the web backend makes it a drop-in web-product framework.

**Sources:** [Toga documentation](https://toga.beeware.org/en/stable/), [Toga platforms](https://toga.beeware.org/en/stable/reference/platforms.html), [Briefcase documentation](https://briefcase.beeware.org/en/stable/).
