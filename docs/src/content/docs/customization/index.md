---
title: Customization
description: Shape Markbridge's output without forking — custom renderers, tags, and handlers.
---

Markbridge is built to be customized without monkey-patching or forking. There are two layers:

- **[Customizing the renderer](/customization/customizing-renderer/)** — build a reusable `Renderer`: override or drop tags, swap the escaper, post-process the output.
- **[Extending Markbridge](/customization/extending/)** — teach a parser tags it doesn't know, and render them with your own Tags.

Most jobs need only the first; reach for the second when your source has tags the defaults don't cover.
