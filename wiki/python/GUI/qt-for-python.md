---
description: "Qt for Python: PySide6 and PyQt bindings for a mature cross-platform UI toolkit."
---

# Qt for Python: PySide and PyQt

Qt for Python is the official **PySide6** binding; PyQt is a separate, widely used binding with different licensing and release arrangements. Both expose Qt Widgets, Qt Quick/QML, networking, graphics, and tooling. Desktop support is the clear baseline; mobile and WebAssembly are Qt platform/deployment questions that require binding- and release-specific proof of concept.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes | Yes | Conditional | Conditional | Conditional |

## Pros

- Mature toolkit, broad widgets, strong model/view architecture, designer tools, and industrial adoption.
- Excellent choice for feature-rich desktop software, hardware tools, and applications needing complex views.
- PySide6 is official and Qt APIs are extensively documented.

## Criticisms and trade-offs

- Learning Qt's object model, signals/slots, event loop, and packaging is substantial.
- Apps can be large, and distribution has platform-specific complexity.
- Licensing needs early review: Qt/PySide and PyQt options are not interchangeable. WebAssembly and mobile routes are not a simple `pip install` experience.

## Use it when

Choose PySide6 (or PyQt after a license decision) for serious desktop applications. Do not choose it solely because Qt itself has mobile/WebAssembly capabilities—prove that exact Python deployment path first.

**Sources:** [Qt for Python](https://doc.qt.io/qtforpython-6/), [distribution guidance](https://doc.qt.io/qtforpython-6/deployment/deployment-pyinstaller.html), [Qt licensing](https://www.qt.io/licensing/).
