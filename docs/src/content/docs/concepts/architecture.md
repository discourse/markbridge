---
title: Architecture
description: The three-phase pipeline that turns markup into Markdown.
---

Markbridge is built around a **Parse → AST → Render** pipeline. Each phase has a single responsibility and doesn't know about the others. The parse and AST stages are renderer-agnostic; Discourse-flavored Markdown is what the shipped renderer produces.

<figure class="diagram">
  <img class="diagram-light" src="/diagrams/architecture.svg" alt="Three-phase pipeline: Input (BBCode / HTML / MediaWiki / XML) → AST (Document tree) → Discourse Markdown">
  <img class="diagram-dark" src="/diagrams/architecture-dark.svg" alt="Three-phase pipeline: Input (BBCode / HTML / MediaWiki / XML) → AST (Document tree) → Discourse Markdown">
</figure>

## Phase 1 — parse

A format-specific parser consumes the input and produces an `AST::Document`. There are four parsers today:

- `Parsers::BBCode::Parser` — token scanner + handler registry (stateful handler API).
- `Parsers::HTML::Parser` — Nokogiri fragment walker (stateless handler API).
- `Parsers::TextFormatter::Parser` — Nokogiri XML walker for the s9e format.
- `Parsers::MediaWiki::Parser` — line-based wikitext parser with no handler registry.

All four produce the same AST node types.

## Phase 2 — the AST

The AST is a tree of `AST::Node` instances. It's renderer-agnostic: nothing in the tree knows about Markdown.

```
Node (base)
├── Text (leaf)
├── LineBreak, HorizontalRule (leaf)
└── Element (container, has children)
    ├── Document (root)
    ├── Inline: Bold, Italic, Underline, Strikethrough, Superscript, Subscript
    ├── Block: Quote, List, ListItem, Code, Spoiler, Heading, HorizontalRule
    └── Content: Url, Image, Attachment, Color, Size, Align, Table, TableRow, TableCell
```

Adjacent `Text` nodes auto-merge on insert, which keeps the tree small. `Element` validates that its children are `AST::Node` instances.

## Phase 3 — render

`Renderers::Discourse::Renderer` walks the tree. For each node it looks up a `Tag` in the `TagLibrary` and calls `tag.render(element, interface)`. The interface carries a `RenderContext` — an immutable parent chain that lets tags ask "am I inside a list?" or "what's my depth?" without passing state around manually.

Parent lookups are cached per-context in a hash, so `has_parent?` is O(1) regardless of tree depth.

## Design patterns in use

- **Composite** — `Element` contains children forming a tree.
- **Strategy** — BBCode uses pluggable closing strategies (Strict, Reordering).
- **Registry** — `HandlerRegistry` for parsers, `TagLibrary` for the renderer.
- **Visitor** — the renderer dispatches AST nodes to tag implementations.
- **Immutable context** — `RenderContext` creates new instances instead of mutating.

## Why this shape

- **Parsers don't know about Markdown.** You can add a new output format without touching them.
- **The renderer doesn't know about BBCode or HTML.** You can add a new input format without touching it.
- **Registries keep customization from forking the core.** Add a handler, add a tag — no subclassing required.

## Next

- [The AST](/concepts/ast/) — node types and invariants
- [Parsers](/concepts/parsers/) — how each parser works
- [Renderers](/concepts/renderers/) — how tags and the rendering interface fit together
- [Performance](/concepts/performance/) — where the pipeline is tuned
