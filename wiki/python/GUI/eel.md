---
description: "Eel: an archived Python and HTML/JavaScript desktop-shell library."
---

# Eel

Eel hosts a local Python web server and opens an HTML/JavaScript GUI in a browser or Chromium app window, exposing calls in both directions. It is included because it appeared in the original research list, but the upstream repository explicitly says it is effectively unmaintained and archived.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Legacy desktop shell | Legacy desktop shell | Legacy desktop shell | No | No | Local browser UI |

## Pros

- Very small conceptual bridge between Python and familiar HTML/CSS/JavaScript.
- Can be useful when maintaining an existing internal utility with a local browser UI.

## Criticisms and trade-offs

- **Do not start a new project with it:** upstream says it is effectively unmaintained and the repository is archived.
- Requires a local server/browser and maintains a custom RPC boundary between Python and JavaScript.
- It is not an Electron replacement for complex applications and has no mobile story.

## Use it when

Only use Eel for short-term maintenance or a tightly constrained existing deployment. For new web-shell work, investigate [pywebview](pywebview.md) or a maintained web UI framework.

**Sources:** [Eel repository and maintenance notice](https://github.com/python-eel/Eel).
