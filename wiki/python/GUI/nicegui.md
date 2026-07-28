---
description: "NiceGUI: a Python-first web UI framework with optional native-window packaging."
---

# NiceGUI

NiceGUI builds browser UIs from Python using a server-backed, reactive approach. It can open in a browser and documents native-mode desktop windows; its core delivery model is still a web application, not a native iOS/Android application framework.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Browser/native mode | Browser/native mode | Browser/native mode | Browser | Browser | Yes |

## Pros

- Fast path from Python code to modern browser UI, dashboards, and internal applications.
- A rich component catalog and straightforward data binding reduce frontend ceremony.
- Web delivery reaches every platform with a browser; desktop native mode can suit local tools.

## Criticisms and trade-offs

- It needs a server/Python runtime and a browser or web-view client, which changes offline, latency, scaling, and security design.
- “Runs on mobile” generally means mobile browser compatibility, not App Store/Play Store native packaging.
- Teams needing custom frontend behavior may still need to understand the underlying web stack.

## Use it when

Use NiceGUI for Python-owned web apps, operations consoles, and local tools. Select a mobile-native framework when device APIs or app-store distribution are requirements.

**Sources:** [NiceGUI documentation](https://nicegui.io/documentation), [native mode](https://nicegui.io/documentation/section_configuration_deployment#native_mode), [project repository](https://github.com/zauberzeug/nicegui).
