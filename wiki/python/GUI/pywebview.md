---
description: "pywebview: a lightweight native desktop window hosting an HTML UI with Python integration."
---

# pywebview

pywebview creates a native desktop window around the operating system's web-view implementation and provides a bridge to Python. It is a shell for an HTML/CSS/JavaScript UI—not a Python widget toolkit and not browser/mobile delivery itself.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Yes | Yes | Yes | No | No | No |

## Pros

- Lets a team reuse normal web UI skills while retaining local Python access and native window chrome.
- Lighter architectural commitment than Electron for many desktop utilities.
- Choice of native web-view backend can reduce bundled runtime weight.

## Criticisms and trade-offs

- You still own the JavaScript/HTML frontend; it is not a Python-only UI solution.
- Rendering and feature behavior depend on each platform's web-view backend, so test per operating system.
- No first-party mobile or ordinary web-hosting target.

## Use it when

Choose pywebview for a maintained desktop application with an HTML frontend and local Python services. Use a web framework directly if deployment in browsers is the goal.

**Sources:** [pywebview documentation](https://pywebview.flowrl.com/), [architecture guide](https://pywebview.flowrl.com/guide/architecture.html).
