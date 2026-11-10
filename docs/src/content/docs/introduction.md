---
title: Introduction
description: What Markbridge is, how it works, and where to go from here.
---

Markbridge is a Ruby library that converts BBCode, HTML, MediaWiki wikitext, and s9e\TextFormatter XML to Markdown. You can convert one document or millions of forum posts. You can also look at the parsed content and change how it is written.

<figure class="diagram">
  <img class="diagram-light" src="/diagrams/architecture.svg" alt="Three-phase pipeline: Input (BBCode / HTML / MediaWiki / XML) → AST (Document tree) → Discourse Markdown">
  <img class="diagram-dark" src="/diagrams/architecture-dark.svg" alt="Three-phase pipeline: Input (BBCode / HTML / MediaWiki / XML) → AST (Document tree) → Discourse Markdown">
</figure>

Every conversion has three steps:

1. **Parse.** A parser for your format reads the input and builds a tree, the AST. It never raises on bad markup. Tags it does not know are counted, so you can review them.
2. **Normalize.** Markup can nest things that Markdown cannot, like a link inside a link or a list inside bold. This step rewrites those parts of the tree.
3. **Render.** The renderer walks the tree and writes Markdown.

The tree has the same node types for every input format, and nothing in it knows about Markdown. The renderer that ships with Markbridge writes Markdown for Discourse. You can write your own renderer for the same tree.

## When to use it

Use Markbridge when you have content in one of the four formats and need it as Markdown, or when you want to work with its structure: find all links, replace images, drop colors.

Migrating a forum to Discourse is the main use case, and Markbridge has what such a migration needs:

- A count of the tags no parser handler knew, per post.
- Errors per post instead of a failed run.
- Your own AST nodes for uploads, users and topics, which your importer resolves later.

The [migration guide](/migrating/overview/) explains that workflow.

## Find your way around

- **[Get started](/getting-started/)** installs the gem and runs a first conversion.
- **[Format guides](/format-guides/)** list what each parser reads and what it becomes.
- **[Customization](/customization/)** covers the renderer options and your own tags and handlers.
- **[Concepts](/concepts/)** explains the AST, the parsers, the renderer and performance.
- **[Migrating to Discourse](/migrating/overview/)** is the workflow for a forum migration.
