---
title: AST normalization
description: The pass that rewrites the AST so the renderer only sees markup the target format can express.
---

Markup can nest things that Markdown cannot:

- a link inside a link,
- a list, a table or a quote inside bold, a heading or a link,
- a code block inside italic text.

Written as they are, they give broken Markdown. Of two nested links only the inner one works, and the outer one shows as text. The blank lines around a list end the bold around it, and the `**` show as text.

`Markbridge::Normalizer` walks the AST once before rendering and rewrites these parts. It is on by default. The tags of the renderer can stay simple for that reason: the rules about what may nest in what are in one place, here.

## Where it runs

```
parse → yield(ast) → normalize → render
```

`yield(ast)` is the block you can pass to a `*_to_markdown` call. The normalizer runs after it, so what you change in the block is normalized too. It runs for every input format and for `Markbridge.render`, because the rules come from Markdown, not from the input.

## The default rules

The default rules are what CommonMark allows. Markdown that breaks one of them is not read back as the tree it was written from:

- **No link inside a link**, at any depth. The inner link is removed and its text stays in the outer link.
- **A block inside an inline container is moved out.** Inline containers are the nodes that hold a line of text: links, headings, and the formatting nodes (`Bold`, `Italic`, `Underline`, …). The blocks are `List`, `Table`, `Quote`, `Details`, `HorizontalRule`, `Align`, `Poll` and `Event`.
- **A fenced or multi-line code block inside an inline container is moved out.** A one-line code span is fine.
- **A block spoiler inside an inline container is moved out.** That is an `AST::Spoiler` with `block: true`. An inline spoiler is fine.
- **No heading inside a heading.** The inner heading is removed and its text stays in the outer one.

When a block is moved out and the texts on its two sides would touch, a space goes between them. This also holds for the text in front of the container when the block was the first thing in it. With the block there they were on two lines, and an HTML parser has trimmed the whitespace at the line edges: `<i>Run <pre>…</pre> and wait</i>` becomes `*Run and wait*` and the code block.

Rules that are a matter of taste are not built in. An image inside a link, `[![alt](src)](url)`, is valid Markdown, so the default keeps it. If you want images moved out of links, add a rule (see below).

## Strategies

A rule names a parent class, a child class and what to do with the child, the strategy:

| Strategy | Effect |
|---|---|
| `:keep` | Leave it where it is. Nothing is reported. |
| `:hoist_after` | Move the node out and put it right after the outermost parent the rule matches. An image in bold text in a link, with a rule for images in links, goes after the whole link. The order of the document stays the same. |
| `:unwrap` | Remove the element and put its children in its place. This is what happens to a link in a link: `[[text](inner)](outer)` becomes `[text](outer)`. |
| `:textify` | Replace the node and everything in it with its plain text (`@name` for a mention). |
| `:drop` | Remove it. |
| a lambda | `->(boundary, node) { … }` returns one of the symbols above, an Array of nodes to put in its place, or `nil` to remove it. `boundary` is the parent the rule matched. |

A formatting node (bold, italic, color, …) that is empty after a move is removed, so no `****` is left behind. A link is kept even when empty, because it is written as its URL.

## Diagnostics

Every change is reported in the diagnostics of the result:

<!-- spec:before
input = "[url=/a][url=/b]x[/url][/url]"
-->
```ruby
conversion = Markbridge.convert(input, format: :bbcode)
conversion.diagnostics[:normalization]
# => [{ parent: "Url", child: "Url", strategy: :unwrap, count: 1 }]
```

In a migration, log these per post. They show where content was moved, and which kind of source markup causes it. The key is missing when nothing changed.

## Turn it off or add rules

`normalize:` takes `true` (the default), `false` (no normalizing), or your own `Normalizer`:

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

Build your normalizer once and pass it to every conversion. It keeps no state between calls, so one instance works for all of them, also from several threads.

How rules are matched:

- A rule for a pair of classes that already has one replaces it. This is how you change a default.
- A rule also matches subclasses, of the parent and of the child. A rule for a more specific class wins. See [AST subclasses](/customization/extending/#ast-subclasses).

`Markbridge::Normalizer.default` returns a new normalizer with the default rules, for you to change. `Markbridge::Normalizer.shared_default` is the frozen one that `normalize: true` uses.

## Check a tree without changing it

`violations` applies the same rules and only reports:

<!-- spec:before
ast = Markbridge.parse_bbcode("[url=/a][url=/b]x[/url][/url]").ast
-->
```ruby
Markbridge::Normalizer.default.violations(ast)
# => [{ parent: "Url", child: "Url", strategy: :unwrap }]
```

Use it in your tests to make sure that the trees your own handlers build need no rewriting. Or run it over all your posts to see what the normalizer would do before you turn it on. After `normalize`, `violations` returns an empty list: one pass fixes everything.
