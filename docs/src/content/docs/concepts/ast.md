---
title: The AST
description: Node types, invariants, and how the tree gets built.
---

Every parser builds an abstract syntax tree (AST). The tree holds the content and its structure: this text is bold, this is a list with three items. It does not hold how the input wrote that, and not how Markdown writes it.

You work with the AST when you want to look at what a document contains, change it before it is rendered, or add node types of your own.

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
    │   ├── AST::Subscript
    │   ├── AST::Insertion         — added text, <ins>
    │   ├── AST::Deletion          — removed text, <del>
    │   └── AST::Highlight         — highlighted text, <mark>
    ├── Block-level
    │   ├── AST::Paragraph
    │   ├── AST::Heading           — level
    │   ├── AST::Quote
    │   ├── AST::Spoiler           — title, block (inline unless block is set)
    │   └── AST::Details           — collapsible [details] section
    ├── Content
    │   ├── AST::Url               — href attribute
    │   ├── AST::Email             — email address
    │   ├── AST::Image             — src, alt, width, height
    │   ├── AST::Attachment
    │   ├── AST::Code              — language and block flag
    │   └── AST::Color, AST::Size, AST::Align
    ├── Lists
    │   ├── AST::List              — ordered / unordered
    │   └── AST::ListItem
    └── Tables
        ├── AST::Table
        ├── AST::TableRow
        └── AST::TableCell     — header, colspan, rowspan
```

## Rules of the tree

- **Children are `AST::Node` objects.** `Element#<<` raises for anything else.
- **Text nodes next to each other merge.** Add `Text("a")` and then `Text("b")`, and the element has one child, `Text("ab")`.
- **Leaves have no children.** `Text`, `LineBreak` and `HorizontalRule` are a `Node`, not an `Element`.
- **Attributes are read-only.** To change a node, build a new one and put it in its place with `replace_child`. `<<` and `replace_children` change the children of an element.

## Building and inspecting

```ruby
doc = AST::Document.new
bold = AST::Bold.new
bold << AST::Text.new("Hello, ")
bold << AST::Text.new("world")   # merged into one Text("Hello, world")
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

`replace_child(old_node, new_node)` puts a new node where a direct child was. You can do that while you walk the tree: every element is walked on a copy of its child list. The walk still goes into the node you replaced, not into the new one, and it may not visit children you add.

## Code spans and blocks

`AST::Code.new(language: "ruby", block: true)` forces a fenced block, even for one line. Without `block: true`, single-line content renders as a code span and multiline content renders as a fenced block. Empty code nodes produce no output.

## Why one AST for all formats

Four parsers share one renderer because they build the same node types. A parser for a fifth format only has to build these nodes, and normalizing and rendering work as they are. A second renderer, for plain text or HTML, only has to walk the tree.
