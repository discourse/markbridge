# MediaWiki Parser Guide

This document describes the MediaWiki parser in Markbridge, its architecture, supported syntax, and how to extend it.

## Overview

The MediaWiki parser converts [MediaWiki wikitext](https://www.mediawiki.org/wiki/Help:Formatting) into Markbridge's AST. It supports the most common MediaWiki formatting constructs used in wiki pages.

**Location:** `Markbridge::Parsers::MediaWiki::Parser`

**Key features:**
- Two-level architecture: line-based block parser + character-based inline parser
- Extensible HTML-like tag handling via `InlineTagRegistry`
- Depth limiting for inline recursion (MAX_INLINE_DEPTH = 20)
- Zero dependencies (pure Ruby)

## Architecture

```
Input → Line Splitter → Block Parser → AST
                            ↓
                      InlineParser (per line)
                            ↓
                      InlineTagRegistry (HTML-like tags)
```

### Why Two Levels?

MediaWiki syntax has fundamentally different patterns at the block and inline levels:

**Block-level** constructs are line-based:
- Headings: `== Heading ==`
- Lists: `* item` / `# item`
- Preformatted: lines starting with a space
- Horizontal rules: `----`
- Paragraphs: separated by blank lines

**Inline** constructs are character-based:
- Bold/italic: `'''bold'''` / `''italic''`
- Links: `[[Page|text]]` / `[url text]`
- HTML-like tags: `<code>`, `<s>`, `<br>`, etc.

This is fundamentally different from BBCode's uniform `[tag]...[/tag]` syntax, which is why the MediaWiki parser uses a different architecture. See [comparison.md](comparison.md) for a detailed comparison.

## Supported Syntax

### Block-Level

| Syntax | Description | AST Node |
|--------|-------------|----------|
| `= H1 =` through `====== H6 ======` | Headings (levels 1-6) | `Heading` |
| `* item` | Unordered list (`**` for nesting) | `List` + `ListItem` |
| `# item` | Ordered list (`##` for nesting) | `List(ordered: true)` + `ListItem` |
| `----` | Horizontal rule (4+ dashes) | `HorizontalRule` |
| ` leading space` | Preformatted text | `Code` |
| `<pre>...</pre>` | Preformatted block | `Code` |
| Blank line | Paragraph separator | (closes lists, separates paragraphs) |

### Inline

| Syntax | Description | AST Node |
|--------|-------------|----------|
| `'''text'''` | Bold | `Bold` |
| `''text''` | Italic | `Italic` |
| `'''''text'''''` | Bold + Italic | `Bold` > `Italic` |
| `[[Page]]` | Internal link | `Url(href: "Page")` |
| `[[Page\|display]]` | Internal link with display text | `Url(href: "Page")` |
| `[url text]` | External link | `Url(href: url)` |
| `<code>...</code>` | Inline code (raw) | `Code` |
| `<nowiki>...</nowiki>` | Escape wiki markup (raw) | `Text` |
| `<s>...</s>` / `<del>...</del>` | Strikethrough | `Strikethrough` |
| `<u>...</u>` / `<ins>...</ins>` | Underline | `Underline` |
| `<sup>...</sup>` | Superscript | `Superscript` |
| `<sub>...</sub>` | Subscript | `Subscript` |
| `<br>` | Line break | `LineBreak` |

## Usage

### Basic Usage

```ruby
parser = Markbridge::Parsers::MediaWiki::Parser.new
ast = parser.parse("'''bold''' and ''italic''")
```

### With Custom Tags

Register additional HTML-like tags via the `InlineTagRegistry`:

```ruby
# Block form (extends defaults)
parser = Markbridge::Parsers::MediaWiki::Parser.new do |registry|
  registry.register("mark", :formatting, Markbridge::AST::Bold)
  registry.register("tt", :raw, Markbridge::AST::Code)
end
ast = parser.parse("<mark>highlighted</mark>")

# Or pass a pre-built registry
registry = Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
  r.register("mark", :formatting, Markbridge::AST::Bold)
end
parser = Markbridge::Parsers::MediaWiki::Parser.new(handlers: registry)
```

### Via Top-Level API

```ruby
# Parse to AST
ast = Markbridge.parse_mediawiki("== Hello ==\nWorld")

# Convert to Markdown
markdown = Markbridge.mediawiki_to_markdown("'''bold''' text")
```

## InlineTagRegistry

The `InlineTagRegistry` controls how HTML-like tags (`<tag>...</tag>`) are handled within inline content. It supports three tag types:

| Type | Behavior | Example |
|------|----------|---------|
| `:raw` | Content preserved verbatim, not parsed for wiki markup | `<code>`, `<nowiki>` |
| `:formatting` | Content IS parsed for nested wiki markup | `<s>`, `<u>`, `<sup>` |
| `:self_closing` | No content, produces a leaf AST node | `<br>` |

### Registration API

```ruby
registry = Markbridge::Parsers::MediaWiki::InlineTagRegistry.new

# Raw tag (content not parsed)
registry.register("code", :raw, Markbridge::AST::Code)

# Special: nowiki uses nil element_class (content becomes literal text)
registry.register("nowiki", :raw, nil)

# Formatting tag (content parsed for wiki markup)
registry.register("s", :formatting, Markbridge::AST::Strikethrough)

# Self-closing tag
registry.register("br", :self_closing, Markbridge::AST::LineBreak)

# Query
registry.known?("code")  # => true
registry["code"]          # => Entry(type: :raw, element_class: Code)
```

## Components

### Parser (`parser.rb`)

The main entry point. Splits input into lines, classifies each line (heading, list, preformatted, blank, or content), and builds block-level AST nodes. Delegates inline content to `InlineParser`.

### InlineParser (`inline_parser.rb`)

Character-by-character parser for inline content within a single line. Handles apostrophe-based formatting, bracket links, and HTML-like tags (via registry). Creates new `InlineParser` instances recursively for nested content, with depth limiting at `MAX_INLINE_DEPTH` (20).

### InlineTagRegistry (`inline_tag_registry.rb`)

Registry mapping HTML-like tag names to their handling type and AST node class. Provides `default` and `build_from_default` factory methods.

## Limitations

- **Templates** (`{{template}}`) are not supported
- **Tables** (`{| ... |}`) are not supported
- **Categories** (`[[Category:...]]`) are treated as regular links
- **Magic words** (`__TOC__`, `__NOTOC__`) are not recognized
- **Nested formatting edge cases** — MediaWiki's apostrophe-based formatting has complex disambiguation rules that are only partially implemented
