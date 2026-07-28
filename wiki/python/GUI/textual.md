---
description: "Textual: a Python framework for rich terminal user interfaces."
---

# Textual

Textual is a Python framework for rich terminal user interfaces (TUIs), with CSS-like styling and a reactive model. It runs wherever a suitable terminal runs; that portability is different from shipping a graphical native or browser application.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Terminal | Terminal | Terminal | Terminal app/SSH | Terminal app/SSH | Browser demo tools |

## Pros

- Excellent keyboard-first UX, SSH friendliness, and low-bandwidth remote operation.
- Modern layout, testing, and styling capabilities compared with traditional console libraries.
- A strong choice for developer tools, administrative consoles, and terminal-native workflows.

## Criticisms and trade-offs

- It is not a GUI framework in the conventional windowed sense; terminal capability varies by emulator.
- Touch/mobile use and consumer-facing visual design are poor matches.
- Browser-oriented tools in the ecosystem do not turn every Textual app into a web application.

## Use it when

Choose Textual when the terminal is a product feature, not merely a fallback. Do not use it to satisfy a native desktop/mobile GUI requirement.

**Sources:** [Textual documentation](https://textual.textualize.io/), [Textual project](https://github.com/Textualize/textual).
