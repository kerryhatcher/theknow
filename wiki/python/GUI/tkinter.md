---
description: "Tkinter: Python's standard interface to the Tcl/Tk GUI toolkit."
---

# Tkinter

Tkinter is Python's standard interface to Tcl/Tk and is normally shipped with CPython installers. It is a desktop toolkit rather than a mobile or web framework; themed `ttk` widgets improve the default control set.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes | Yes | No | No | No |

## Pros

- No separate Python GUI dependency for normal CPython installations; abundant examples and long-term stability.
- Simple event-loop model and good fit for forms, utilities, and teaching.
- `ttk` provides themed controls without adopting a new framework.

## Criticisms and trade-offs

- The core widget set and layout APIs feel dated for modern, highly branded interfaces.
- Complex responsive layouts, rich data views, and sophisticated graphics require more custom work than in Qt or web stacks.
- Packaging and native integrations remain application responsibilities.

## Use it when

Use Tkinter for a focused desktop tool where low dependency cost matters. Skip it for mobile, browser, or design-heavy products.

**Sources:** [Python Tkinter documentation](https://docs.python.org/3/library/tkinter.html), [themed Tk guide](https://docs.python.org/3/library/tkinter.ttk.html).
