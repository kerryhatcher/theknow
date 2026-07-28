---
description: "Dear PyGui: a fast, GPU-accelerated Python GUI framework for custom desktop tools."
---

# Dear PyGui

Dear PyGui is an immediate-mode, GPU-accelerated Python GUI framework built around Dear ImGui. It targets desktop applications and is especially suited to engineering, visualization, and internal-tool interfaces rather than native-control fidelity.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes | Yes | No | No | No |

## Pros

- High performance and useful plotting/drawing primitives for data- or tool-heavy UIs.
- Immediate-mode programming can be quick for compact, dynamic utilities.
- Self-contained visual style avoids native-widget variations.

## Criticisms and trade-offs

- Immediate-mode APIs are a poor conceptual fit for every form-heavy business UI and can make large application state harder to organize.
- The appearance is deliberately custom rather than platform-native.
- Desktop-only; accessibility and polished consumer-app patterns should be evaluated carefully.

## Use it when

Choose it for performance-sensitive desktop tools, instrumentation, or visualization. Prefer Qt or a web UI for accessibility-intensive, conventional applications.

**Sources:** [Dear PyGui documentation](https://dearpygui.readthedocs.io/en/latest/), [project repository](https://github.com/hoffstadt/DearPyGui).
