---
title: The AST
description: Node types, invariants, and how the tree gets built.
---

Every parser produces an abstract syntax tree (AST). The tree stores content and structure independently of the input syntax and renderer.

## Node hierarchy

```
AST::Node (base)
├── Leaves
│   ├── AST::Text                  — string content
│   ├── AST::MarkdownText          — pre-rendered Markdown passthrough
│   ├── AST::LineBreak
│   └── AST::HorizontalRule
├── Discourse-specific leaves
│   ├── AST::Event                 — calendar event reference
│   ├── AST::Mention               — @username reference
│   ├── AST::Poll                  — Discourse poll reference
│   └── AST::Upload                — uploaded-file reference
└── AST::Element (container)
    ├── AST::Document              — root node
    ├── Inline formatting
    │   ├── AST::Bold
    │   ├── AST::Italic
    │   ├── AST::Underline
    │   ├── AST::Strikethrough
    │   ├── AST::Superscript
    │   └── AST::Subscript
    ├── Block-level
    │   ├── AST::Paragraph
    │   ├── AST::Heading           — level
    │   ├── AST::Quote
    │   ├── AST::Spoiler
    │   └── AST::Details           — collapsible [details] section
    ├── Content
    │   ├── AST::Url               — href attribute
    │   ├── AST::Email             — email address
    │   ├── AST::Image             — src, alt attributes
    │   ├── AST::Attachment
    │   ├── AST::Code              — language and block flag
    │   └── AST::Color, AST::Size, AST::Align
    ├── Lists
    │   ├── AST::List              — ordered / unordered
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
- **Node attributes are read-only.** You can edit the tree with `<<`, `replace_child`, and `replace_children`.

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

Use `each_descendant` to visit nodes in depth-first order, or `descendants(klass)` to collect nodes of a given class. Subclasses match too.

```ruby
parse = Markbridge.parse_bbcode("[b]Hello[/b] [url=/about]About[/url]")
links = parse.ast.descendants(Markbridge::AST::Url)
links.map(&:href) # => ["/about"]
```

`replace_child(old_node, new_node)` replaces a direct child at the same position. During traversal, each element uses a copy of its child list. Replacing a child is supported, but the walk continues through the original node. Added children may not be visited during that walk.

## Code spans and blocks

`AST::Code.new(language: "ruby", block: true)` forces a fenced block, even for one line. Without `block: true`, single-line content renders as a code span and multiline content renders as a fenced block. Empty code nodes produce no output.

## Why a shared AST matters

The AST is what lets four parsers share one renderer. Any new input format — Markdown, AsciiDoc, some vendor-specific XML — only has to produce the same node types, and everything downstream works without changes. Similarly, a second renderer (say, plain text or HTML) only has to walk the existing AST.
