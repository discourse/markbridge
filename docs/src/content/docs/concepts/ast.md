---
title: The AST
description: Node types, invariants, and how the tree gets built.
---

The AST is the pipeline's waist: every parser produces it, and the renderer consumes it. It deliberately knows nothing about input or output formats.

## Node hierarchy

```
AST::Node (base)
├── AST::Text                  — leaf, holds a string
├── AST::LineBreak             — leaf
├── AST::HorizontalRule        — leaf
└── AST::Element (container)
    ├── AST::Document          — root node
    ├── Inline formatting
    │   ├── AST::Bold
    │   ├── AST::Italic
    │   ├── AST::Underline
    │   ├── AST::Strikethrough
    │   ├── AST::Superscript
    │   └── AST::Subscript
    ├── Content
    │   ├── AST::Url           — href attribute
    │   ├── AST::Image         — src, alt attributes
    │   ├── AST::Attachment
    │   ├── AST::Code          — optional lang
    │   ├── AST::Heading       — level
    │   ├── AST::Color, AST::Size, AST::Align
    │   ├── AST::Quote
    │   └── AST::Spoiler
    ├── Lists
    │   ├── AST::List          — ordered / unordered
    │   └── AST::ListItem
    └── Tables
        ├── AST::Table
        ├── AST::TableRow
        └── AST::TableCell
```

## Invariants

- **Children are always `AST::Node` instances.** `Element#<<` validates on insert.
- **Adjacent `Text` nodes auto-merge.** Inserting `Text("a")` then `Text("b")` results in a single `Text("ab")` child — not two.
- **Leaves have no children.** `LineBreak` and `HorizontalRule` extend `Node` directly, not `Element`, and will reject children.
- **No public setters.** Once a node is built, its attributes are read-only (`attr_reader`, not `attr_accessor`).

## Building and inspecting

```ruby
doc = AST::Document.new
bold = AST::Bold.new
bold << AST::Text.new("Hello, ")
bold << AST::Text.new("world")   # auto-merged into one Text("Hello, world")
doc << bold

doc.children.first.class           # => AST::Bold
doc.children.first.children.length # => 1
```

## Walking the tree

The renderer walks depth-first, dispatching each node through the `TagLibrary`. For custom traversal, iterate `children` yourself — there's no built-in visitor because the rendering interface already covers the common cases.

## Why a shared AST matters

The AST is what lets four parsers share one renderer. Any new input format — Markdown, AsciiDoc, some vendor-specific XML — only has to produce the same node types, and everything downstream works without changes. Similarly, a second renderer (say, plain text or HTML) only has to walk the existing AST.
