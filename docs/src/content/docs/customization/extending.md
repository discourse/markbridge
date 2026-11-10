---
title: Extending Markbridge
description: Add support for new tags, customize rendering, and swap behavior without patching core.
---

Every forum has tags of its own: a `[callout]`, a `[youtube]`, an `<aside class="note">`. The default handlers do not know them, so their content is kept and the tag is lost. This page shows how to teach Markbridge such a tag.

A tag takes three things:

```
tag in the source  →  handler  →  AST node  →  renderer tag  →  Markdown
```

- A **handler** tells the parser what to build when it sees the tag.
- An **AST node** holds what the tag means. Use a built-in class when one fits, or write your own.
- A **renderer tag** writes the node as Markdown. A built-in node already has one.

Handlers and renderer tags are registered next to the defaults. You do not change the gem.

## Adding a custom BBCode tag

### 1. Define the AST node

```ruby
module Markbridge
  module AST
    class Callout < Element
      attr_reader :variant

      def initialize(variant: "info")
        super()
        @variant = variant
      end
    end
  end
end
```

### 2. Write the handler

<!-- spec:continue -->
```ruby
module Markbridge
  module Parsers
    module BBCode
      module Handlers
        class CalloutHandler < BaseHandler
          def initialize
            @element_class = AST::Callout
          end

          attr_reader :element_class

          def on_open(token:, context:, registry:, tokens: nil)
            variant = token.attrs[:option] || "info"
            context.push(AST::Callout.new(variant:))
          end
        end
      end
    end
  end
end
```

### 3. Register the handler

<!-- spec:continue -->
```ruby
handlers =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |registry|
    registry.register("callout", Markbridge::Parsers::BBCode::Handlers::CalloutHandler.new)
  end
```

### 4. Write the renderer tag

For a short tag, pass a block to `Tag.new`:

```ruby
callout_tag =
  Markbridge::Renderers::Discourse::Tag.new do |element, interface|
    context = interface.with_parent(element)
    inner = interface.render_children(element, context:)
    if interface.html_mode?
      "<aside>#{inner}</aside>"
    else
      "> [!#{element.variant.upcase}]\n> #{inner.gsub("\n", "\n> ")}\n"
    end
  end
```

### 5. Build a renderer with the tag

<!-- spec:continue -->
```ruby
renderer = Markbridge.discourse_renderer(
  tags: { Markbridge::AST::Callout => callout_tag },
)
```

Every other AST class keeps its default tag. [Customizing the renderer](/customization/customizing-renderer/) has the other options.

### 6. Use it

<!-- spec:continue -->
```ruby
result = Markbridge.bbcode_to_markdown(
  "[callout=warning]Check this setting.[/callout]",
  handlers:,
  renderer:,
)
result.markdown
# => "> [!WARNING]\n> Check this setting."
```

## The rendering interface

A tag gets `(element, interface)`. The element is the node to write. The interface gives the tag the output of its children and answers questions about where the node is in the tree:

| Method | Purpose |
|---|---|
| `render_children(element, context:)` | The children as Markdown. Pass `context: interface.with_parent(element)`, so the children know their parent. A tag that writes a closing BBCode tag right after the children also passes it, as `following: "[/mytag]"`. Discourse would read the closing tag as part of a bare URL in front of it, so a link at the end is then written as `[url](url)` |
| `render_tokens(element, context:)` | The children as inline tokens (`Markbridge::Renderers::Discourse::Inline::Tokens`), for a tag that returns tokens, see below |
| `render_default(node)` | The node written by the tag Markbridge ships for it, even when you replaced that tag. Use it in a tag that handles only some nodes itself |
| `with_parent(element)` | A new context with `element` as the parent |
| `find_parent(klass)` | The nearest ancestor of an AST class, or nil |
| `has_parent?(klass)` | Whether an ancestor of a class exists |
| `count_parents(klass)` | How many ancestors of a class there are, for the depth of nested lists |
| `previous_sibling(element)`, `next_sibling(element)`, `sibling(element, offset:)` | The neighbors of an element among the children of its parent (nil at the edges) |
| `previous_list(element)` | The last list in front of the element, or the node whose output ends with one, with nothing visible between them (nil when there is none) |
| `choose_list_marker(node, ordered:)`, `list_marker(node)` | The marker for the items of a list, or of a node that writes a list of its own: the one the list in front did not use, `- ` or `* `, `1. ` or `1) `. `list_marker` returns the marker chosen for a node in this render call, `ListItemTag` and `HorizontalRuleTag` read it |
| `leading_list(node, children: false)`, `trailing_list(node, children: false)` | The list the output of `node` starts or ends with, as its tag says through `Tag#leading_list` and `Tag#trailing_list` (nil when it starts or ends with something else). With `children: true` the answer for the first or last child with something in it, for a tag whose output starts or ends with the children's, like the plain form of `DetailsTag` |
| `block_context?(element)` | Whether the element stands where a block can stand |
| `html_mode?` | True inside a CommonMark HTML block — a Tag that returns a String must emit raw HTML without a blank line, or write its Markdown through `markdown_island`; the serializer takes care of it for tokens |
| `markdown_island(markdown, block:)` | Markdown that Discourse has to read as Markdown (the BBCode of a plugin, an upload, a placeholder for one), in the form of the place: as it is, with blank lines around a block, or an island in a `<div>` inside an HTML block |

Most tags need only the first few rows. The list methods are for tags that write a list or stand next to one.

## Tags that return inline tokens

A tag that writes a block or a pair of BBCode tags returns a String, as above. For inline formatting a String is not enough. Whether `**` makes text bold depends on the characters next to it: `**bold**text` works, `**bold **text` does not. A tag does not see its neighbors, so it cannot know.

The built-in tags for emphasis, links, images, superscript and subscript therefore do not write Markdown. They return tokens, and the renderer's serializer writes the tokens when it has the whole line and sees every neighbor. Your tag can do the same:

```ruby
require "markbridge"

Tokens = Markbridge::Renderers::Discourse::Inline::Tokens

class HighlightTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    tokens = interface.render_tokens(element, context: interface.with_parent(element))
    tokens.unshift(Tokens.open(:strong)) << Tokens.close(:strong)
  end
end
```

`render_tokens` returns the output of the children as an Array of tokens. A child that returned finished Markdown is a String in it. `Tokens` builds all kinds of tokens:

| Token | Written as |
|---|---|
| a `String` | finished Markdown, as it is |
| `Tokens.text(string)` | the string, escaped like text (`Tokens::LABEL` for a link label, `Tokens::VERBATIM` for none) |
| `Tokens.open(name)` … `Tokens.close(name)` | `**`, `*`, `~~` or `[u]…[/u]` around the content (`:strong`, `:em`, `:s`, `:u`), with whitespace at the edges outside the markers and an HTML fallback where the markers would not work. Every paragraph of the content gets its own markers |
| `Tokens.link_open(destination)` … `Tokens.link_close` | `[content](destination)` |
| `Tokens.bare_url(href)` | the href alone where linkify links it, `[href](href)` where text is glued to it |
| `Tokens.image(src:, alt:, width:, height:)` | `![alt\|WxH](src)` |
| `Tokens.code(content)` | a code span with a backtick run longer than any run in the content |
| `Tokens.hard_break` | a newline; `<br>` on a line that holds nothing else, after a blank line nothing, right after an `html` token `<br>` |
| `Tokens.html(string)` | raw HTML, as it is; a newline right after it becomes `<br>`, so an opening tag is never alone on its line, where it would open an HTML block |
| `Tokens.placeholder(text, like:)` | `text`, as it is, joined with its neighbors as if `like` stood there; for a placeholder that a later step replaces, see [Placeholders](/migrating/placeholders/#tell-markbridge-what-replaces-the-placeholder) |

Inside an HTML block (`interface.html_mode?`) the serializer writes the HTML form of every token: `<strong>`, `<a href>`, `<img>`, `<br>`. A tag that returns tokens does not have to care about HTML mode. A tag that returns a String does, see [below](#rendering-inside-html-blocks).

### Markers over several paragraphs

Inline markup cannot go over a blank line. The blank line ends the paragraph, and the markers show as text. A tag that writes its own markers into a String has to close them in front of every blank line and open them again after it. `Markbridge::Renderers::Discourse::Paragraphs.wrap(content, "[x]", "[/x]")` does that and keeps whitespace at the edges of every paragraph outside the markers. `Paragraphs.map(content) { |paragraph| … }` yields the paragraphs for anything else. Content with a code fence counts as one paragraph.

### What a tag may return

A String or an Array of tokens. `nil` or anything else raises a `TypeError`. A tag that handles only some nodes returns `interface.render_default(node)` for the others.

## Rendering inside HTML blocks

A Markdown table cannot hold everything. A table with a `colspan`, with rows of different length, or with a list or a line break in a cell is written as an HTML table. Inside an HTML table Markdown is not read: `**bold**` would show with its asterisks. So everything inside such a table has to be written as HTML, and `interface.html_mode?` tells a tag that it is in one.

A tag that returns a String has two ways to do that:

1. **Write HTML.** Return the HTML form of the node, like `<aside>` in the callout example above. Escape text and attribute values from the source with `Markbridge::Renderers::Discourse::HtmlEscaper`. Write no blank line: a blank line ends the HTML block.
2. **Write a Markdown island.** Some Markdown has no HTML form, like the BBCode of a plugin or an upload. Return it through `interface.markdown_island(markdown, block:)`. Inside an HTML block that puts the Markdown between blank lines inside a `<div>`, where Discourse reads it as Markdown again. Outside an HTML block it is the Markdown itself, with blank lines around it when `block: true`.

Prefer HTML when there is an element for it. An island is a block of its own, so it adds space around the content.

The children of your node are rendered in HTML mode too. You do not have to pass that on.

### Test it

Markbridge ships an RSpec example that renders a tag in HTML mode and fails when Markdown markers are in the output. Put Markdown characters into the content, so the check has something to find:

<!-- spec:before
require "rspec"
require "markbridge/all"
CalloutTag = Markbridge::Renderers::Discourse::Tags::BoldTag
Callout = Markbridge::AST::Bold
-->
```ruby
require "markbridge/rspec"

RSpec.describe CalloutTag do
  it_behaves_like "an html_mode safe tag" do
    let(:tag) { described_class.new }
    let(:element) do
      node = Callout.new
      node << Markbridge::AST::Text.new("body *with* Markdown characters")
      node
    end
  end
end
```

Use your own classes in place of `CalloutTag` and `Callout`. When the children need tags of your own, define `markbridge_renderer` inside the block with a renderer that has them. The example checks only the form of the output. Whether the output is the right one is a test you write yourself.

## AST subclasses

Sometimes a built-in node is nearly right: you want a code block, but you also want to know later that it came from a `[php]` tag. Subclass the node. A subclass gets the renderer tag and the normalizer rules of its superclass:

```ruby
class LegacyCode < Markbridge::AST::Code
end
```

A `LegacyCode` node is written by `CodeTag`, and the normalizer rules for `AST::Code` apply to it. A tag or a rule registered for the subclass itself wins over the inherited one.

To write only the children of the subclass, and not use the inherited tag:

<!-- spec:before
class LegacyCode < Markbridge::AST::Code; end
-->
```ruby
renderer = Markbridge.discourse_renderer(
  tags: { LegacyCode => Markbridge::Renderers::Discourse::Tag::PASSTHROUGH }
)
```

`unregister:` does not do that for a subclass: without a tag of its own, the inherited tag writes it. See [AST normalization](/concepts/normalization/) for rules for your own classes.

## HTML and TextFormatter parsers

Handlers for these two parsers are simpler than BBCode handlers, because the input is already a tree. A handler is an object with `#process(element:, parent:)`. It adds a node to `parent` and returns the node that the children of the element go into, or `nil` to skip the children.

<!-- spec:before
input = "<details>hi</details>"
-->
```ruby
class SpoilerHandler < Markbridge::Parsers::HTML::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Spoiler
  end

  attr_reader :element_class

  def process(element:, parent:)
    spoiler = Markbridge::AST::Spoiler.new
    parent << spoiler
    spoiler
  end
end

html_handlers =
  Markbridge::Parsers::HTML::HandlerRegistry.build_from_default do |registry|
    registry.register("details", SpoilerHandler.new)
  end

Markbridge.html_to_markdown(input, handlers: html_handlers)
```

The TextFormatter registry works the same way, with two differences: a handler gets a third keyword, `#process(element:, parent:, processor:)`, and the element names are uppercase (`"SPOILER"`), like in the XML.

## Replacing a built-in renderer tag

To write a built-in node differently, register your own tag for its class. This one changes links that start with a slash and leaves the rest to the default tag:

```ruby
renderer = Markbridge.discourse_renderer(
  tags: {
    Markbridge::AST::Url =>
      Markbridge::Renderers::Discourse::Tag.new do |element, interface|
        next interface.render_default(element) unless element.href&.start_with?("/")

        link = Markbridge::AST::Url.new(href: "https://forum.example.com#{element.href}")
        element.children.each { |child| link << child }
        interface.render_default(link)
      end,
  }
)
```

## Wrapping a default handler

Often the default handler is right for most cases and you want to change only a few. `HandlerRegistry#overlay` gives you the handler that is registered for a tag and registers what your block returns:

<!-- spec:before
class LoggingQuoteHandler
  def initialize(default:); @default = default; end
  def auto_closeable?; @default.auto_closeable?; end
  def element_class; @default.element_class; end
  def on_open(token:, context:, registry:, tokens: nil)
    @default.on_open(token:, context:, registry:, tokens:)
  end
  def on_close(token:, context:, registry:, tokens: nil)
    @default.on_close(token:, context:, registry:, tokens:)
  end
end
-->
```ruby
handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
handlers.overlay("quote") do |default|
  LoggingQuoteHandler.new(default:)
end
```

The BBCode, HTML and TextFormatter registries have `overlay`. `default` is `nil` when no handler was registered for the tag. The MediaWiki `InlineTagRegistry` works differently, see the [MediaWiki guide](/format-guides/mediawiki/#customizing).

In BBCode, be careful with tags that have aliases. `url`, `link` and `iurl` all build an `AST::Url`, and the parser finds the handler for a closing tag by the element that is open. All aliases therefore need the same handler object. `overlay` would build one per name, so use `register` with all names:

<!-- spec:before
class LoggingUrlHandler
  def initialize(default:); @default = default; end
  def auto_closeable?; @default.auto_closeable?; end
  def element_class; @default.element_class; end
  def on_open(token:, context:, registry:, tokens: nil)
    @default.on_open(token:, context:, registry:, tokens:)
  end
  def on_close(token:, context:, registry:, tokens: nil)
    @default.on_close(token:, context:, registry:, tokens:)
  end
end
handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
-->
```ruby
default_url = handlers["url"]
handlers.register(%w[url link iurl], LoggingUrlHandler.new(default: default_url))
```

## In a migration

A migration has tags whose target does not exist yet when the post is converted: a link to a topic that is not imported, an upload, a mention. The same three parts apply. The renderer tag writes a placeholder, and your importer finds the nodes again with `conversion.ast.descendants(...)`. [Placeholders](/migrating/placeholders/) is the guide for that.

## Which way for which problem

| Problem | Way |
|---|---|
| A tag the parser does not know | Register a handler |
| A known tag that should be written differently | `tags: { ASTClass => MyTag.new }` |
| A default handler that is right in most cases | `HandlerRegistry#overlay` |
| A default tag that is right in most cases | Your own tag that calls `interface.render_default(node)` |
| Another output format | A renderer of your own for the same AST |
