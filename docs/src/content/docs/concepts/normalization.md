---
title: AST normalization
description: The pass that rewrites the AST so the renderer only sees markup the target format can express.
---

Markup can nest elements in ways Markdown can't express: a link inside a link, a block element inside an inline container (a link label, but also bold or a heading), a fenced code block inside emphasis. If the renderer printed these as-is, the Markdown would break — the inner link wins and the outer one turns into text, a block's blank lines break out of the emphasis around it.

`Markbridge::Normalizer` walks the AST once, between the parse-time `yield` hook and rendering, and rewrites it so the renderer only gets markup the target format can express. It runs **by default**. The renderer's tags stay simple string emitters; the rules about what may nest in what live here instead.

## Where it runs

```
parse → yield(ast) → normalize → render
```

Because it runs after the `yield` hook, changes you make to the AST in that block are normalized too. It runs for every source format and for `Markbridge.render`, because normalization is about the *target* format, not the source.

## The default rules

The default rules are CommonMark legality. Break one and the Markdown doesn't parse back as the tree meant:

- **No link inside a link**, at any depth (§6.3). The inner link is unwrapped.
- **A block inside an inline container is moved out.** An inline container holds inline content only. This isn't link-specific: emphasis (`Bold`, `Italic`, …) and headings are inline containers too, so a poll inside bold or a list inside a heading is handled the same way as a block inside a link. The block nodes cover `List`, `Table`, `Quote`, `Details`, `HorizontalRule`, `Align`, and the Discourse `Poll`/`Event` nodes.
- **A fenced or multi-line code block inside an inline container is moved out.** A one-line code span is fine.

Discourse-specific policy is **not** built in. Moving an image out of a link, for example, is a rule you add yourself (see below) — a linked image (`[![alt](src)](url)`) is valid CommonMark, so the default leaves it alone.

## Strategies

Each match resolves to one strategy:

| Strategy | Effect |
|---|---|
| `:keep` | Allow it. Records a decision and keeps it out of the report. |
| `:hoist_after` | Move the node out and place it right after the outermost matching ancestor, keeping document order. An image in a bold that sits in a link moves after the whole link (out of both). The walker only moves a node out to a sibling; it never puts one into a wrapper it wasn't already in. |
| `:unwrap` | Remove the element and put its children in its place. The built-in case is a link in a link: `[[text](inner)](outer)` becomes `[text](outer)` — the inner href is dropped, its text stays under the outer link. |
| `:textify` | Replace the subtree with its plain text (`@name` for a mention, the joined text otherwise). |
| `:drop` | Remove it. |
| callable | `->(boundary, node) { … }` returning a strategy symbol, an `Array<AST::Node>` to put in its place, or `nil` to drop it. For anything the built-in strategies don't cover. |

A formatting wrapper (bold, italic, color, …) left empty after a hoist or drop is removed, so no empty `**` `**` markers remain. A link is the exception — an empty link is kept, because it renders as a plain URL.

## Diagnostics

Every change is reported through the same channel as `unknown_tags`:

<!-- spec:before
input = "[url=/a][url=/b]x[/url][/url]"
-->
```ruby
conversion = Markbridge.convert(input, format: :bbcode)
conversion.diagnostics[:normalization]
# => [{ parent: "Url", child: "Url", strategy: :unwrap, count: 1 }]
```

For a migration this feeds per-post warnings and shows which sources produce broken trees. The key is absent when nothing changed.

## Opting out and customizing

`normalize:` takes `true` (default — the shared normalizer), `false` (skip), or a `Normalizer` instance:

<!-- spec:before
input = "[b]hi[/b]"
-->
```ruby
# Skip normalization
Markbridge.convert(input, format: :bbcode, normalize: false)

# Add your own rules on top of the defaults
normalizer = Markbridge::Normalizer.default
normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :hoist_after)
Markbridge.convert(input, format: :bbcode, normalize: normalizer)
```

Build a customized normalizer once and reuse it. `#normalize` and `#violations` keep no state on the instance, so one frozen instance is safe for every conversion, also across threads — passing your own is as fast as the default path. A rule for a `(parent, child)` pair that already exists is replaced, so your `#rule` calls override the defaults. Matching is by exact class (`instance_of?`), so a rule for `AST::Url` doesn't catch a subclass.

`Markbridge::Normalizer.shared_default` is the default normalizer, built once and frozen; the `normalize: true` path uses it. Don't mutate it — call `.default` for a fresh, customizable one.

## Validation

The same rules, without changing the tree:

<!-- spec:before
ast = Markbridge.parse_bbcode("[url=/a][url=/b]x[/url][/url]").ast
-->
```ruby
Markbridge::Normalizer.default.violations(ast)
# => [{ parent: "Url", child: "Url", strategy: :unwrap }]
```

Two uses: assert in your own suite that the trees your parsers and tag fixtures build have no violations, or run it as a lint over a corpus without changing any output. After a `normalize`, `violations` returns nothing — normalization is a single pass.
