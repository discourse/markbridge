---
title: Introduction
description: What Markbridge is, how it works, and where to go from here.
---

Markbridge is a Ruby library that converts **BBCode, HTML, MediaWiki wikitext, and s9e/TextFormatter XML** into Discourse-flavored Markdown. The core is small and predictable: every conversion runs the same three steps, and you can customize or extend each one.

<figure class="diagram">
  <img class="diagram-light" src="/diagrams/architecture.svg" alt="Three-phase pipeline: Input (BBCode / HTML / MediaWiki / XML) → AST (Document tree) → Discourse Markdown">
  <img class="diagram-dark" src="/diagrams/architecture-dark.svg" alt="Three-phase pipeline: Input (BBCode / HTML / MediaWiki / XML) → AST (Document tree) → Discourse Markdown">
</figure>

1. **Parse** — a format-specific parser reads your input and builds an `AST::Document`. Unknown tags are tracked, never raised.
2. **AST** — a renderer-agnostic tree. The same shape comes out no matter which format went in.
3. **Render** — the Discourse renderer walks the tree and emits Markdown.

The parse and AST stages know nothing about Discourse — "Discourse-flavored" is just what the shipped renderer produces. You could point a different renderer at the same AST.

## Four input formats, one renderer

Markbridge ships four parsers that all feed the same Discourse renderer: [BBCode](/format-guides/bbcode/), [HTML](/format-guides/html/), [MediaWiki](/format-guides/mediawiki/), and [s9e/TextFormatter XML](/format-guides/textformatter/). Pick the one that matches your source — [Getting Started](/getting-started/) shows the exact method for each.

## When to use it

Markbridge is built for **forum migrations into Discourse** — that's the flagship use case, with tooling for placeholders, unknown-tag auditing, and per-post failure isolation. But nothing in the parse or AST stages is migration-specific, so it fits any job that needs predictable, repeatable markup → Markdown conversion.

## Find your way around

- **[Getting Started](/getting-started/)** — install and run your first conversion.
- **Format guides** — exactly how each input maps to Markdown.
- **Customization** — build a reusable renderer, and add your own tags and handlers.
- **Concepts** — the architecture, the AST, the parsers and renderer, and performance.
- **[Migrating to Discourse](/migrating/overview/)** — the full forum-migration workflow.
