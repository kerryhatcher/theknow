---
description: "PyGObject and GTK: GObject-introspection bindings for GTK applications."
---

# PyGObject and GTK

PyGObject provides Python bindings through GObject Introspection, commonly used with GTK and the GNOME platform. GTK is a capable desktop toolkit with its strongest integration and distribution experience on Linux.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes, package carefully | Yes, package carefully | No | No | No |

## Pros

- First-class choice for GNOME/Linux applications and access to the broader GObject ecosystem.
- Native accessibility and desktop integration on its home platform.
- Introspection reduces the need for handwritten bindings across many GObject libraries.

## Criticisms and trade-offs

- Windows and macOS distribution is possible but generally brings more dependency/packaging friction than Linux.
- GTK's design language may not meet expectations for a macOS- or Windows-native consumer app.
- No native mobile or browser target.

## Use it when

Choose PyGObject/GTK for Linux-first or GNOME-integrated products. Do a packaging spike before promising equal Windows/macOS support.

**Sources:** [PyGObject overview](https://pygobject.gnome.org/), [GTK documentation](https://docs.gtk.org/gtk4/).
