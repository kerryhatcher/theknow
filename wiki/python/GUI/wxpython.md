---
description: "wxPython: Python bindings for wxWidgets and native desktop controls."
---

# wxPython

wxPython exposes the wxWidgets C++ toolkit to Python. It emphasizes native-looking desktop controls on Linux, macOS, and Windows, making it a direct peer to Tkinter and Qt for desktop applications.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes | Yes | No | No | No |

## Pros

- Mature desktop toolkit with a native-control approach and extensive traditional widgets.
- Useful APIs for desktop integrations such as menus, printing, and dialogs.
- Cross-desktop code retains platform conventions better than custom-rendered toolkits.

## Criticisms and trade-offs

- It has a smaller current mindshare and ecosystem than Qt/Tkinter, so examples and third-party integrations may be harder to find.
- API style reflects its long history and can feel verbose.
- No mobile or browser target.

## Use it when

Choose wxPython when a conventional native desktop app is the entire requirement and wxWidgets' control set fits. Prefer Qt for a larger modern desktop ecosystem.

**Sources:** [wxPython overview](https://wxpython.org/pages/overview/), [documentation](https://docs.wxpython.org/).
