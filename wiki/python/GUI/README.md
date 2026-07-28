---
description: "A decision-oriented survey of Python GUI and UI frameworks."
---

# Python GUI framework research

This survey turns the original [scratchpad](../GUI.md) into decision notes. It covers every named project there and adds **wxPython**, **PyGObject/GTK**, **pywebview**, and **Textual** because they fill important native-desktop, web-shell, and terminal-UI niches.

## Read this first

“Cross-platform” can mean three different things: one codebase that produces native binaries, a web app reachable on every device, or a desktop application with a web view. The [ranking](ranking.md) scores the first two separately where that distinction matters. A web checkmark means browser delivery, not an App Store-ready native application.

## Framework map

| Primary model | Frameworks | Best fit |
| --- | --- | --- |
| Native/custom-rendered app | [Kivy](kivy.md), [BeeWare/Toga](beeware-toga.md), [Flet](flet.md), [Qt for Python](qt-for-python.md), [Tkinter](tkinter.md), [Dear PyGui](dear-pygui.md), [wxPython](wxpython.md), [PyGObject/GTK](pygobject-gtk.md) | Installed applications |
| Python-first web UI | [NiceGUI](nicegui.md), [Reflex](reflex.md), [Remi](remi.md) | Browser-based products and internal tools |
| HTML/JS desktop shell | [Eel](eel.md), [pywebview](pywebview.md) | Reusing web UI while retaining local Python access |
| Terminal UI | [Textual](textual.md) | Keyboard-first tools, SSH, and local developer utilities |

## Quick starting points

- Need the broadest *documented* Linux/macOS/Windows/iOS/Android/web story: start with [Flet](flet.md), then validate its packaging and control coverage with a spike.
- Need native controls and mobile stores, with a Python-only stack: evaluate [BeeWare/Toga](beeware-toga.md); budget time for its younger ecosystem.
- Need mature desktop tooling and extensive widgets: use [Qt for Python](qt-for-python.md), normally **PySide6** unless PyQt's licensing is the intended choice.
- Need a web product where Python owns UI and backend: compare [NiceGUI](nicegui.md) and [Reflex](reflex.md).
- Need a built-in, durable desktop dependency: use [Tkinter](tkinter.md) for modest interfaces.

Each note contains the delivery matrix, strengths, limitations/criticisms, and a recommendation boundary. Claims reflect official documentation reviewed on 2026-07-28; validate release-specific support before committing to a platform.

## Sources and selection method

The original scratchpad's Python Wiki, Python GUIs, Python Guide, Flet, and Dear PyGui links were reviewed. Platform statements are anchored primarily in each project's official documentation: [Kivy](https://kivy.org/doc/stable/gettingstarted/intro.html), [Toga](https://toga.beeware.org/en/stable/), [Flet](https://flet.dev/docs/), [Qt for Python](https://doc.qt.io/qtforpython-6/), [Tkinter](https://docs.python.org/3/library/tkinter.html), [Remi](https://remi.readthedocs.io/), [NiceGUI](https://nicegui.io/documentation), [Reflex](https://reflex.dev/docs/getting-started/introduction/), [Dear PyGui](https://dearpygui.readthedocs.io/), [wxPython](https://wxpython.org/pages/overview/), [PyGObject](https://pygobject.gnome.org/), [pywebview](https://pywebview.flowrl.com/), and [Textual](https://textual.textualize.io/).
