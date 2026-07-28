---
description: "Remi: Python-defined widgets rendered as HTML in a web browser."
---

# Remi

Remi is a pure-Python GUI library that renders its widgets as HTML in a browser and serves the application from Python. Its portability comes from browser access; it is not an application-packaging framework for native desktop or mobile binaries.

| Linux | macOS | Windows | iOS | Android | Web |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Browser | Browser | Browser | Browser | Browser | Yes |

## Pros

- Small, approachable route to a Python-controlled web UI without writing a separate frontend.
- Browser delivery works across operating systems and devices.
- Useful for prototypes, device-control panels, and LAN/internal utilities.

## Criticisms and trade-offs

- Its component ecosystem and modern application conventions are less extensive than newer web UI frameworks.
- A local/server-hosted browser architecture introduces networking and deployment concerns.
- It should not be represented as native iOS, Android, or desktop support.

## Use it when

Use Remi for a compact browser UI backed by Python. Prefer NiceGUI or Reflex for a more full-featured modern web-application direction.

**Sources:** [Remi documentation](https://remi.readthedocs.io/en/latest/), [project repository](https://github.com/rawpython/remi).
