---
title: Renderers
description: How the Discourse Markdown renderer walks the AST.
---

The renderer takes an `AST::Document` and produces a Markdown string. It lives under `Markbridge::Renderers::Discourse` and has three collaborators:

- **`Renderer`** — walks the tree.
- **`TagLibrary`** — maps `AST::Node` classes to `Tag` implementations.
- **`RenderingInterface`** — what a `Tag` actually sees when rendering.

## The rendering loop

```
renderer.render(document)
  for each child node:
    tag = tag_library[child.class] || tag_library.resolve(child.class)
    render with the tag, or render the children if no tag matches
```

The renderer holds no state beyond the running output and the context. All decisions about markup (`**`, `_`, backticks, etc.) live in the individual `Tag` classes.

## Tags

A `Tag` is any class (or block) that responds to `render(element, interface)` and returns finished Markdown:

```ruby
class SpoilerTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    context = interface.with_parent(element)
    content = interface.render_children(element, context:)
    return "<details><summary>Spoiler</summary>#{content}</details>" if interface.html_mode?

    "[spoiler]#{content}[/spoiler]"
  end
end
```

For simple cases, the block constructor is often enough:

```ruby
Markbridge::Renderers::Discourse::Tag.new do |element, interface|
  context = interface.with_parent(element)
  "[spoiler]#{interface.render_children(element, context:)}[/spoiler]"
end
```

Inline formatting works differently. Whether `**` or `*` means what it should depends on what stands next to it, so the built-in emphasis tags do not write the markers themselves. They return inline tokens, and the renderer's serializer (`Markbridge::Renderers::Discourse::Inline::Serializer`) writes them with the neighbors in view: it keeps whitespace at the edges outside the markers, falls back to `<strong>` where `**` would not work, and writes the HTML form inside an HTML block.

```ruby
class BoldTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    tokens = interface.render_tokens(element, context: interface.with_parent(element))
    tokens.unshift(Inline::Tokens.open(:strong)) << Inline::Tokens.close(:strong)
  end
end
```

A tag that returns a String next to a tag that returns tokens is fine: the serializer writes the String as it is and joins it with its neighbors by its first and last character.

## The rendering interface

`Tag` implementations never see the renderer directly. They receive a `RenderingInterface` that exposes only what a tag should need:

| Method | Use |
|---|---|
| `render_children(element)` | Recurse into children, write their output as Markdown |
| `render_tokens(element)` | The output of the children as inline tokens, for a tag that returns tokens |
| `with_parent(element)` | Return a new context that treats `element` as parent |
| `find_parent(klass)` | Walk ancestors for a specific class |
| `has_parent?(klass)` | Boolean ancestor check |
| `count_parents(klass)` | How deep a specific ancestor is (nested lists, quotes) |
| `previous_sibling(element)`, `next_sibling(element)`, `sibling(element, offset:)` | The neighbors of an element among the children of its parent |
| `previous_list(element)` | The last list in front of the element, or the node whose output ends with one, with nothing visible between them |
| `choose_list_marker(node, ordered:)`, `list_marker(node)` | The marker for the items of a list, the one the list in front did not use; and the marker chosen for a node in this render call |
| `leading_list(node, children: false)`, `trailing_list(node, children: false)` | The list the output of `node` starts or ends with, as its tag says (`Tag#leading_list`, `Tag#trailing_list`); with `children: true` the answer for the first or last child with something in it |
| `block_context?(element)` | Block vs. inline position |
| `html_mode?` | True inside a CommonMark HTML block — a Tag that returns a String must emit raw HTML without a blank line, or write its Markdown through `markdown_island`; the serializer takes care of it for tokens |
| `markdown_island(markdown, block:)` | Markdown that Discourse has to read as Markdown (the BBCode of a plugin, an upload, a placeholder for one): as it is, with blank lines around a block; inside an HTML block an island in a `<div>`, `<div>\n\n…\n\n</div>` |

The interface decouples tags from the renderer: you could write a second renderer (HTML, plain text, JSON) and reuse every tag by providing a compatible interface.

## RenderContext

Behind the interface is a `RenderContext` — an immutable, linked parent chain. Creating a child context (via `with_parent`) links a new instance to the current one; the old one is untouched. `has_parent?` / `find_parent` walk that chain, so each nested level is a single fixed-size allocation rather than a copied parent array, and nesting depth stays shallow in practice.

A child context does not change the context used by its siblings.

## TagLibrary

The Discourse renderer ships with a default library mapping each built-in AST class to its Tag. `TagLibrary.default` returns a fresh copy each call (mutating it doesn't affect other callers).

For most customization, prefer the `Markbridge.discourse_renderer(tags:, unregister:)` factory over hand-mutating a library — it gives you a complete, reusable Renderer:

<!-- spec:before
MyUrlTag = Class.new(Markbridge::Renderers::Discourse::Tag) do
  def render(element, interface) = interface.render_children(element)
end
-->
```ruby
RENDERER = Markbridge.discourse_renderer(
  tags: { Markbridge::AST::Url => MyUrlTag.new },     # override
  unregister: [Markbridge::AST::Color],               # render children only
)
```

The renderer checks the node's class, then its nearest registered ancestor class. If neither has a tag, it renders only the children. To render only the children of a subclass with an inherited tag, register `Tag::PASSTHROUGH`. See [AST subclasses](/customization/extending/#ast-subclasses).

For lower-level use, `TagLibrary.new.auto_register!` discovers convention-paired classes (`BoldTag` → `AST::Bold`, etc.) under `Markbridge::Renderers::Discourse::Tags::*`. Consumer-defined tag classes still need explicit registration.

## Output cleanup

After the tree walk, the renderer's `Postprocessor` runs a small cleanup pass on the joined output:

- Collapse runs of 3+ newlines to 2.
- Strip whitespace-only lines.
- Trim leading/trailing whitespace.

The default postprocessor is `Markbridge::Renderers::Discourse::Postprocessor::DEFAULT`. Pass a custom one (or a subclass) via `Markbridge.discourse_renderer(postprocessor:)` to change or extend the cleanup. Calling `Renderer#render` directly returns the *un*-postprocessed string.

## Writing a new renderer

Because the AST is renderer-agnostic, writing (say) a plain-text renderer is a matter of implementing a new `Renderer` that walks the AST and emits whatever you want. Re-using the `Tag` / `TagLibrary` pattern is recommended — it gives you the same extension points for free.
