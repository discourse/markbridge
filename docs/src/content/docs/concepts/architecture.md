---
title: Architecture
description: The steps that turn markup into Markdown, and why they are separate.
---

Markbridge converts in steps: parse the input into a tree, normalize the tree, render it. Each step knows nothing about the others. That is why four input formats can share one renderer, and why you can change one step without touching the rest.

<figure class="diagram">
  <img class="diagram-light" src="/diagrams/architecture.svg" alt="Three-phase pipeline: Input (BBCode / HTML / MediaWiki / XML) → AST (Document tree) → Discourse Markdown">
  <img class="diagram-dark" src="/diagrams/architecture-dark.svg" alt="Three-phase pipeline: Input (BBCode / HTML / MediaWiki / XML) → AST (Document tree) → Discourse Markdown">
</figure>

## Parse

A parser reads one input format and returns an `AST::Document`. There are four:

| Parser | How it works |
|---|---|
| `Parsers::BBCode::Parser` | A scanner turns the input into tokens. Handlers turn the tokens into nodes. |
| `Parsers::HTML::Parser` | Nokogiri parses the HTML. Handlers turn its elements into nodes. |
| `Parsers::TextFormatter::Parser` | The same, for the XML of s9e\TextFormatter. |
| `Parsers::MediaWiki::Parser` | Reads wikitext line by line, and the markup inside a line with a second parser. |

A parser does not raise on bad markup. A tag without a handler is counted, and its content is parsed as if the tag were not there. See [Parsers](/concepts/parsers/).

## The AST

The AST is a tree of `AST::Node` objects: text, line breaks, and elements with children, like `AST::Bold`, `AST::List` or `AST::Table`. Every parser builds the same node types, and no node knows how it is written in Markdown.

Between parsing and rendering the tree is yours. `Markbridge.bbcode_to_markdown(input) { |ast| … }` yields it, and you can replace, add or remove nodes. See [The AST](/concepts/ast/).

## Normalize

Markup can nest things that Markdown cannot: a link inside a link, a list inside bold, a code block inside a heading. `Markbridge::Normalizer` walks the tree once and rewrites these parts, so the renderer only gets trees that Markdown can express. It runs after your block, so your changes are normalized too. It is on by default. See [AST normalization](/concepts/normalization/).

## Render

`Renderers::Discourse::Renderer` walks the tree. For every node it looks up a `Tag` in its `TagLibrary` and calls `tag.render(element, interface)`. The tag returns Markdown.

A tag often needs to know where it is: a list item inside a list inside a quote is indented and prefixed differently from one at the top. The `interface` answers such questions (`has_parent?`, `find_parent`, `previous_sibling`), so a tag keeps no state of its own. See [Renderers](/concepts/renderers/).

## What you can change

| You want to | Change |
|---|---|
| Read a tag the parser does not know | Register a handler in the parser's `HandlerRegistry` |
| Write a node differently | Register a tag with `Markbridge.discourse_renderer(tags:)` |
| Change the content itself | Edit the AST in the block of a `*_to_markdown` call |
| Change what may nest in what | Add a rule to the `Normalizer` |
| Write another output format | Write a renderer that walks the AST |

Handlers and tags are registered, not subclassed into the gem. Your code stays outside of Markbridge, and an update of the gem does not overwrite it. See [Customization](/customization/).
