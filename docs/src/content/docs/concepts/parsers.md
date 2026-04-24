---
title: Parsers
description: How the four parsers work and where they differ.
---

Each parser targets one input format but produces the same AST. They share philosophy (graceful degradation, bounded recursion) but not implementation.

## BBCode parser

**Path:** `Markbridge::Parsers::BBCode::Parser`

A hand-written, two-stage parser:

1. **Scanner** — streams characters and produces `TextToken`, `TagStartToken`, `TagEndToken`. Character-by-character, no regex except for character classes, index-based access to avoid allocations.
2. **Parser** — consumes tokens through a `HandlerRegistry`. Each handler implements `on_open` / `on_close`. A `ParserState` tracks the node stack and enforces the max-depth limit (100).

**Unique to BBCode:** closing strategies. Real-world BBCode often has mismatched tags (`[b][i]text[/b][/i]`). A `ClosingStrategy` decides how to recover:

- `Strict` — auto-close only.
- `Reordering` (default) — look ahead up to 5 tokens to match sequences.

**Handler API:** stateful. Handlers push/pop elements on the parser state stack via `on_open` / `on_close` callbacks.

## HTML parser

**Path:** `Markbridge::Parsers::HTML::Parser`

Thin wrapper over `Nokogiri::HTML.fragment` + a handler registry. Walks the DOM and dispatches each element to a handler.

**Handler API:** stateless — a callable receiving `(element:, parent:)`. It adds an AST node to `parent` and returns either the node to descend into, or `nil` to skip children.

Lambdas count as callables, which keeps quick customizations terse:

```ruby
registry.register("aside", ->(element:, parent:) { ... })
```

Relies on Nokogiri for malformed-HTML recovery — no need for Markbridge to do its own.

## TextFormatter parser

**Path:** `Markbridge::Parsers::TextFormatter::Parser`

Parses the XML format produced by <a href="https://github.com/s9e/TextFormatter" class="nowrap">s9e/TextFormatter</a>. Used primarily for phpBB 3.2+ migrations, where BBCode is stored as parsed XML rather than raw BBCode.

Same stateless handler API as the HTML parser. The main quirks are format-level:

- Roots are `<t>` (plain) or `<r>` (rich).
- Formatted elements use **uppercase** names (`<B>`, `<URL>`).
- `<s>` / `<e>` tags preserve original BBCode markup and are ignored during parsing.

Invalid XML falls back to treating the input as plain text.

## MediaWiki parser

**Path:** `Markbridge::Parsers::MediaWiki::Parser`

Unlike the others, there's no handler registry — wikitext is fixed-syntax. The parser is line-based: it classifies each line (heading, list, table, preformatted, blank, plain) and dispatches accordingly. An `InlineParser` handles intra-line formatting (`'''bold'''`, `[[links]]`, etc.).

Customization for MediaWiki is typically post-parse: transform the AST or register a custom renderer tag. There's no parser-level extension point.

## Shared traits

All four parsers:

- **Don't raise on bad input.** Unknown tags/elements are skipped (children still processed).
- **Return an `AST::Document`.** The root is always a `Document` containing children.
- **Track unknown tags** (on BBCode/HTML/TextFormatter) so you can audit migrations.
- **Normalize line endings** (CRLF → LF) before parsing.

## Picking one

| Input | Use |
|---|---|
| `[b]...[/b]` | BBCode |
| `<p><strong>...</strong></p>` | HTML |
| `<r><B>...</B></r>` | TextFormatter |
| `'''bold''' and [[links]]` | MediaWiki |

If you have a choice (e.g. phpBB 3.2+ stores both), prefer the TextFormatter parser over re-parsing the raw BBCode — it's faster and closer to the source of truth.
