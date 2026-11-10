---
title: Format guides
description: The four input formats Markbridge converts, and how to pick one.
---

Markbridge reads four formats. Each guide lists the tags the parser knows, what they become, and the limits of the parser. Pick the one your source is stored in:

- **[BBCode](/format-guides/bbcode/)** — `[b]…[/b]` tags, as most forum software stores them.
- **[HTML](/format-guides/html/)** — parsed with Nokogiri, so broken HTML is no problem.
- **[MediaWiki](/format-guides/mediawiki/)** — the wikitext of a wiki export.
- **[TextFormatter](/format-guides/textformatter/)** — the XML that s9e\TextFormatter stores. phpBB 3.2+ and Flarum use it.

A forum that uses s9e\TextFormatter stores the XML, not the BBCode the user typed. Use the TextFormatter parser for it.

All four parsers build the same tree and share one renderer, so the same content gives the same Markdown whatever format it came from.
