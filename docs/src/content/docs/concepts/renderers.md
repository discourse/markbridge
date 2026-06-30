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
    tag = tag_library[child.class]
    tag.render(child, interface)
```

The renderer holds no state beyond the running output and the context. All decisions about markup (`**`, `_`, backticks, etc.) live in the individual `Tag` classes.

## Tags

A `Tag` is any class (or block) that responds to `render(element, interface)`:

```ruby
class BoldTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    interface.wrap_inline(interface.render_children(element), "**")
  end
end
```

For simple cases, the block constructor is often enough:

```ruby
Markbridge::Renderers::Discourse::Tag.new do |element, interface|
  "**" + interface.render_children(element) + "**"
end
```

## The rendering interface

`Tag` implementations never see the renderer directly. They receive a `RenderingInterface` that exposes only what a tag should need:

| Method | Use |
|---|---|
| `render_children(element)` | Recurse into children, concatenate output |
| `with_parent(element)` | Return a new interface that treats `element` as parent |
| `find_parent(klass)` | Walk ancestors for a specific class |
| `has_parent?(klass)` | Boolean ancestor check |
| `count_parents(klass)` | How deep a specific ancestor is (nested lists, quotes) |
| `wrap_inline(content, markers)` | Wrap inline content with collapsing markers |
| `block_context?(element)` | Block vs. inline position |
| `html_mode?` | True inside a CommonMark HTML block — Tag must emit raw HTML or wrap output as a Markdown island (`\n\n…\n\n`) |

The interface decouples tags from the renderer: you could write a second renderer (HTML, plain text, JSON) and reuse every tag by providing a compatible interface.

## RenderContext

Behind the interface is a `RenderContext` — an immutable parent chain. Creating a child context (via `with_parent`) allocates a new instance; the old one is untouched. Parent lookups are cached in a hash for O(1) access regardless of tree depth.

This immutability is load-bearing: it keeps the renderer side-effect free during a walk, which makes reasoning about nested tags much simpler.

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
  unregister: [Markbridge::AST::Color],               # drop entirely
)
```

Unknown AST classes (and unregistered ones) fall through to `render_children`, so a node with no registered tag won't crash rendering — it renders its children only, with the surrounding markup discarded.

For lower-level use, `TagLibrary.new.auto_register!` discovers convention-paired classes (`BoldTag` → `AST::Bold`, etc.) under `Markbridge::Renderers::Discourse::Tags::*`. Consumer-defined tag classes still need explicit registration.

## Output cleanup

After the tree walk, the renderer's `Postprocessor` runs a small cleanup pass on the joined output:

- Collapse runs of 3+ newlines to 2.
- Strip whitespace-only lines.
- Trim leading/trailing whitespace.

The default postprocessor is `Markbridge::Renderers::Discourse::Postprocessor::DEFAULT`. Pass a custom one (or a subclass) via `Markbridge.discourse_renderer(postprocessor:)` to change or extend the cleanup. Calling `Renderer#render` directly returns the *un*-postprocessed string.

## Writing a new renderer

Because the AST is renderer-agnostic, writing (say) a plain-text renderer is a matter of implementing a new `Renderer` that walks the AST and emits whatever you want. Re-using the `Tag` / `TagLibrary` pattern is recommended — it gives you the same extension points for free.
