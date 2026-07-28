---
description: "Ranked Python UI-framework choices, weighted toward delivery across desktop, mobile, and web."
---

# Cross-platform ranking

This is a ranking for a team that values one Python-led codebase across **Linux, macOS, Windows, iOS, Android, and the web**. It is not a general popularity ranking. Scores weigh documented target coverage (60%), coherence of the primary programming model (25%), and delivery maturity/maintenance signals (15%). `Native` means a supported app target; `Web` means browser delivery.

| Rank | Framework | Linux | macOS | Windows | iOS | Android | Web | Why it lands here |
| ---: | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| 1 | [Flet](flet.md) | Yes | Yes | Yes | Yes | Yes | Yes | One documented Python-first framework for desktop, mobile, and web. |
| 2 | [BeeWare/Toga](beeware-toga.md) | Yes | Yes | Yes | Yes | Yes | Experimental | Native-widget ambition and broad mobile reach; web is not an equal-production target. |
| 3 | [Kivy](kivy.md) | Yes | Yes | Yes | Yes | Yes | No | Strong established mobile/desktop story, but no first-party browser target. |
| 4 | [NiceGUI](nicegui.md) | Browser | Browser | Browser | Browser | Browser | Yes | A browser UI works everywhere; desktop packaging exists, but it is not native mobile delivery. |
| 5 | [Reflex](reflex.md) | Browser | Browser | Browser | Browser | Browser | Yes | Strong web product model; no native app target. |
| 6 | [Qt for Python](qt-for-python.md) | Yes | Yes | Yes | Conditional | Conditional | Conditional | Outstanding desktop platform; Python mobile/WebAssembly deployment needs Qt-specific validation. |
| 7 | [Remi](remi.md) | Browser | Browser | Browser | Browser | Browser | Yes | Very portable web delivery, with fewer modern product and packaging facilities. |
| 8 | [pywebview](pywebview.md) | Yes | Yes | Yes | No | No | No | Practical desktop shell around HTML; not a browser/mobile framework. |
| 9 | [wxPython](wxpython.md) | Yes | Yes | Yes | No | No | No | Mature native desktop reach only. |
| 10 | [Tkinter](tkinter.md) | Yes | Yes | Yes | No | No | No | Included with Python and dependable for simple desktop software. |
| 11 | [Dear PyGui](dear-pygui.md) | Yes | Yes | Yes | No | No | No | Fast custom-rendered desktop UI, particularly for tools. |
| 12 | [PyGObject/GTK](pygobject-gtk.md) | Yes | Yes | Yes | No | No | No | Best aligned with Linux/GNOME; other desktop targets require more packaging care. |
| 13 | [Textual](textual.md) | Terminal | Terminal | Terminal | Terminal | Terminal | Browser demo | Terminal portability is excellent, but it is deliberately not a native GUI. |
| 14 | [Eel](eel.md) | Legacy | Legacy | Legacy | No | No | Browser shell | The upstream project is archived/effectively unmaintained; do not start new work here. |

## How to interpret the result

1. Prototype the first two candidates that match the intended delivery model, including release signing and a real device—not just a desktop emulator.
2. Treat “browser” as a strength if PWA-style delivery is acceptable. It is not interchangeable with native iOS/Android access, offline behavior, or store distribution.
3. Check licenses early: Qt bindings, platform SDKs, and embedded browser runtimes can affect distribution even when the Python package is open source.

## Near misses and specialized choices

The ordering intentionally penalizes narrow but excellent tools. Qt can easily be the top choice for a desktop engineering application; Dear PyGui for a GPU-heavy internal tool; and Textual for a terminal-first workflow. Read the linked framework notes before using the table as a final selection.
