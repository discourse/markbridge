---
title: Customization
description: Change what Markbridge reads and writes with renderer options, your own tags, and your own handlers.
---

You change Markbridge by registering your own objects, not by patching the gem. There are two levels:

- **[Customizing the renderer](/customization/customizing-renderer/)** — the options of `Markbridge.discourse_renderer`: replace or remove tags, say which plugins the target site has, resolve relative links, change the escaping.
- **[Extending Markbridge](/customization/extending/)** — teach a parser a tag it does not know, and write the renderer tag for it.

Most projects only need the first page. Read the second one when your source has tags the default handlers do not cover.
