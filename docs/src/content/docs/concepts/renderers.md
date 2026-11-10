---
title: Renderers
description: How the Discourse Markdown renderer walks the AST.
---

The renderer takes an `AST::Document` and returns Markdown. This page explains how it does that, which you need to know before you write a tag of your own. To only change options, read [Customizing the renderer](/customization/customizing-renderer/).

The renderer is in `Markbridge::Renderers::Discourse` and has three parts:

- **`Renderer`** walks the tree.
- **`TagLibrary`** says which `Tag` writes which AST class.
- **`RenderingInterface`** is what a tag gets from the renderer: the output of its children and answers about where it is in the tree.

## The rendering loop

```
renderer.render(document)
  for each child node:
    tag = tag_library[child.class] || tag_library.resolve(child.class)
    render with the tag, or render the children if no tag matches
```

The renderer itself knows no Markdown. What a node looks like (`**`, a fence of backticks, `> `) is decided by its tag.

## Tags

A tag is an object with `render(element, interface)` that returns finished Markdown:

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

For a short tag, pass a block to `Tag.new`:

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

A tag never gets the renderer itself. It gets a `RenderingInterface` with what a tag needs:

| Method | Use |
|---|---|
| `render_children(element, context:)` | The children as Markdown. `context:` is optional, pass `with_parent(element)` so the children know their parent |
| `render_tokens(element, context:)` | The children as inline tokens, for a tag that returns tokens |
| `render_default(node)` | The node written by the tag Markbridge ships for it, even when you registered your own |
| `with_parent(element)` | A new context with `element` as the parent |
| `find_parent(klass)` | The nearest ancestor of a class, or nil |
| `has_parent?(klass)` | Whether an ancestor of a class exists |
| `count_parents(klass)` | How many ancestors of a class there are (the depth of a nested list or quote) |
| `previous_sibling(element)`, `next_sibling(element)`, `sibling(element, offset:)` | The neighbors of an element among the children of its parent |
| `previous_list(element)` | The last list in front of the element, or the node whose output ends with one, with nothing visible between them |
| `choose_list_marker(node, ordered:)`, `list_marker(node)` | The marker for the items of a list, the one the list in front did not use; and the marker chosen for a node in this render call |
| `leading_list(node, children: false)`, `trailing_list(node, children: false)` | The list the output of `node` starts or ends with, as its tag says (`Tag#leading_list`, `Tag#trailing_list`); with `children: true` the answer for the first or last child with something in it |
| `block_context?(element)` | Whether the element stands where a block can stand |
| `html_mode?` | True inside a CommonMark HTML block — a Tag that returns a String must emit raw HTML without a blank line, or write its Markdown through `markdown_island`; the serializer takes care of it for tokens |
| `markdown_island(markdown, block:)` | Markdown that Discourse has to read as Markdown (the BBCode of a plugin, an upload, a placeholder for one): as it is, with blank lines around a block; inside an HTML block an island in a `<div>`, `<div>\n\n…\n\n</div>` |

[Extending Markbridge](/customization/extending/#the-rendering-interface) has the same table with more detail on each method.

## RenderContext

The interface gets its answers from a `RenderContext`: the chain of parents of the node that is being rendered. A context is never changed. `with_parent` returns a new one that points to the old one, so a tag cannot change what its siblings see.

## TagLibrary

The default library has a tag for every AST class Markbridge ships. `TagLibrary.default` returns a new copy on every call, so changing it changes nothing for other callers.

You rarely need the library itself. `Markbridge.discourse_renderer(tags:, unregister:)` builds a renderer with your changes on top of the defaults:

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

The renderer looks for a tag for the class of the node, then for the nearest superclass that has one. Without any tag it renders only the children. A subclass that should render only its children, although a superclass has a tag, gets `Tag::PASSTHROUGH`. See [AST subclasses](/customization/extending/#ast-subclasses).

To build a library by hand, start from `TagLibrary.default`, or from `TagLibrary.new.auto_register!`, which registers every tag class in `Markbridge::Renderers::Discourse::Tags` for the AST class of the same name (`BoldTag` for `AST::Bold`). Your own tag classes are not found that way, register them with `library.register(MyNode, MyTag.new)`. Pass the library to the factory as `tag_library:`.

## Output cleanup

Tags write blank lines around their blocks without knowing their neighbors, so the joined output has too many of them. A `Postprocessor` cleans up after the walk:

- Three or more newlines in a row become two.
- A line with only whitespace becomes an empty line.
- Whitespace at the start and the end of the document is removed.

`Markbridge.discourse_renderer(postprocessor:)` takes your own, see [Customizing the renderer](/customization/customizing-renderer/#postprocessor--clean-up-the-final-string). `Renderer#render` returns the output before this cleanup. The `*_to_markdown` methods and `Markbridge.render` return it cleaned up.

## Writing a new renderer

The AST does not depend on the Discourse renderer. A renderer for plain text or HTML is a class that walks the tree and writes what you need. We recommend the same split into a renderer and a library of tags: it gives the users of your renderer the same way to replace one tag.
