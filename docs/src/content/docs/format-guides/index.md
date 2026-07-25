---
title: Format guides
description: The four input formats Markbridge converts, and how to pick one.
---

Markbridge converts four input formats into the same Discourse-flavored Markdown. Each guide lists the tags it supports and how they map to Markdown — pick the one that matches your source:

- **[BBCode](/format-guides/bbcode/)** — forum-classic `[b]...[/b]` tags, and the most feature-rich format.
- **[HTML](/format-guides/html/)** — parsed tolerantly via Nokogiri.
- **[MediaWiki](/format-guides/mediawiki/)** — the wikitext subset you'll find in wiki exports.
- **[TextFormatter](/format-guides/textformatter/)** — the s9e/TextFormatter XML that phpBB 3.2+ stores.

All four feed the same renderer, so the output is consistent no matter which one you start from.
