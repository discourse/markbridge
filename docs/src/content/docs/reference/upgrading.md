---
title: Upgrading
description: Breaking-change notes between Markbridge releases.
---

## Upgrading to 0.4.3

The round-trip specs (see the Testing section of AGENTS.md) found a number of output defects. The fixes change the Markdown for the cases below, so check output assertions that cover them:

- A fenced code block whose content ends with a newline no longer gets a blank line before the closing fence. `<pre><code>x\n</code></pre>` and `[code]x\n[/code]` render as ` ```\nx\n``` `.
- The postprocessor leaves fenced code blocks alone. Blank lines and whitespace-only lines inside a fence stay as they are.
- Inline code picks a backtick delimiter longer than any backtick run in the content, and pads the content with a space when it starts or ends with a backtick or with spaces on both sides: `` `a`b` `` becomes ``` ``a`b`` ```.
- Images carry their alternative text. `AST::Image` has a new `alt:` keyword, the HTML, BBCode and TextFormatter parsers fill it, and the renderer writes `![alt|WxH](src)` in Markdown and `alt="…"` in html_mode. Line breaks in the alt text become spaces. Discourse reads the `|` parts at the end of the alt text as image options (a size, `video`, `audio`, `thumbnail`, `key=value`). When the alt text itself ends in such a part, an empty part follows it, `![screenshot\|800x600|](a.png)`, so Discourse does not resize the image; the alt text gets a `|` at its end.
- Parentheses and backslashes in a link or image destination are escaped: `[text](https://example.com/a\(b\))`. An image destination with whitespace is wrapped in `<…>`, like a link destination already was.
- A run of `#` at the end of a heading gets a backslash, so it stays visible: `### foo \###`. This also applies to a heading that is nothing but `#` characters.
- A horizontal rule inside a list item is written as `* * *`. As `---` it ended the list when it was the first thing in the item.
- A `!` directly in front of a link gets a backslash, so `Look![here](url)` does not cook as an image.
- Two lists of the same kind that follow each other are separated by an HTML comment between blank lines (`<!---->`), so they do not merge into one loose list. Whitespace, line breaks and anything that renders to nothing between the two lists do not count as something between them. A list without items renders to nothing.
- Emphasis or strikethrough whose content starts or ends with punctuation gets the `<!---->` boundary comment when a word character or a strikethrough stands right next to it, for example `item<!---->*\#*`. Without it CommonMark's flanking rules keep the delimiters as text. Unicode punctuation and symbols (`“`, `「`, `€`, ...) at the edge count as punctuation, like ASCII punctuation.
- When a list directly inside a list item has more content of the item after it, a line with an empty HTML comment (`<!---->`) ends the nested list, so the content stays in the outer item instead of becoming a continuation line of the last nested item. The outer list stays tight; a blank line there would make it loose. Whitespace and line breaks between the nested list and the content go. A list inside a quote or an aligned block inside an item is a block with blank lines on both sides.
- An ordered-list marker alone on a line (`1.` or `1)`) is escaped like one followed by text. It cooked to an empty list item before.
- A bare URL with text right next to it (no whitespace between) is written as a link with the URL as its text, `[https://example.com](https://example.com)`, because a Markdown parser does not link it on its own there. The same goes for a bare URL with inline code, emphasis, an image or another inline element right next to it. A bare URL with whitespace around it stays plain and can still onebox. So does one with an opening parenthesis in front of it or with sentence punctuation after it, followed by whitespace or the end of the text: one `,`, or a run of `.`, `!` or `?`, with a `)` in front when the href has no parentheses. markdown-it leaves that punctuation out of the link. Other punctuation, like `:` or `.)`, gives the link form.
- `[url]https://example.com[/url]` without an option takes its href from the text. The URL had a nil href before and was written as escaped plain text, so `a_b` in it ended up as `a%5C_b` in the cooked link.
- Strikethrough whose content starts or ends with `~` is written as `<s>…</s>`. As `~~~x~~` it did not close, and at the start of a line it opened a code fence.
- The postprocessor clears whitespace-only lines before it collapses runs of blank lines, so the blank lines they leave are collapsed too.
- A `[details]` block has a blank line after the opening tag and one before the closing tag. Without them a table at the end of the block took the `[/details]` line as a row, and a `---` at the start of the block made the opening tag a heading. Discourse reads the block the same with or without the blank lines.
- The alt text of an upload and the filename of an attachment upload are escaped like a link label, as the alt text of an image already was: `![a\]b \*c\*|100x200](upload://pic.png)`.
- What is inside an escaped HTML tag is escaped like any text. Only the `<` got a backslash before, and the tag was copied as it was: a backslash in an attribute was lost after cooking, an entity reference in it was decoded. Now `<a href="\*">` is written as `\<a href="\\\*">`.
- Every character of a code fence at the start of a line gets a backslash, also for tildes (`\~\~\~` where it was `\~~~`), and the info string after the fence is escaped like any text. Before, `` ``` f&ouml; *x* `` kept its entity and emphasis.
- A heading stays on one line: a newline in its text becomes a space, and a hard line break in a heading is written as `<br>`. Before, the text after the break left the heading.
- The built-in emphasis tags (`BoldTag`, `ItalicTag`, `StrikethroughTag`, `UnderlineTag`) return inline tokens instead of Markdown, and the renderer's `Inline::Serializer` writes the markers. A custom tag that calls `tag.render` on one of them gets an Array now; `renderer.serialize(output, context)` turns it into Markdown. `RenderingInterface#render_tokens(element)` gives a custom tag the children as tokens. `wrap_inline` has no HTML fallback any more, it only places the markers around the content.
- Strong emphasis whose content starts with emphasis and ends with another emphasis is written with `<strong>` tags: `***a*<!---->*.***` did not cook as strong. One emphasis at one edge, or one spanning the whole content (`***a***`), keeps the markers.
- Whitespace at the edges of emphasis stays outside the HTML fallback as well: `<strong>` alone on a line, with a hard break inside the emphasis, opened an HTML block.
- A backslash in front of trailing whitespace inside emphasis or a link label gets a second backslash, so it does not escape the closing marker.
- An underline whose content starts with `:` gets a backslash in front of the colon: `[u]:x[/u]` at the start of a line read as a link reference definition.
- `UrlTag`, `EmailTag` and `ImageTag` return inline tokens too, and the serializer writes the link, the bare URL or the image. `RenderingInterface#wrap_inline` is gone; a custom tag that wrapped content with it writes the markers itself or returns tokens.
- A bare link with an href that linkify does not link on its own but that is a place on the site (a path, an anchor, a query, a protocol-relative URL) is written as `[/path](/path)` in every position. As plain text it did not link when nothing was glued to it. A bare link whose href is neither, a wiki page name for example, stays plain text in every position, also with text glued to it.
- A mail link without visible text is written as its `mailto:` address instead of an empty link.
- `Markbridge::Renderers::Discourse::Inline::Tokens` is the API for a custom tag that returns inline tokens instead of Markdown; [Extending Markbridge](/customization/extending/) describes the token kinds. A spoiler whose content starts with `:` gets a backslash in front of the colon, like the underline.
- Two lists of the same kind directly inside a list item are separated by a `<!---->` line without blank lines around it, so the outer list stays tight. Between blank lines the comment made the item loose.
- A table with a block in a cell (a list, a quote, a heading, a rule, a code block, a details or aligned block) is written as an HTML table. As a Markdown table the cell showed the block's markers as text. A table whose header row is not its first row is an HTML table too, and keeps its rows in order; the Markdown form moved the header row to the top. In an HTML table the header rows at the top go into `<thead>`, every other row into `<tbody>` in order.
- A table inside a table has no blank lines around it. Inside the outer table's HTML block a blank line ended the block, and the rest was Markdown again.
- A `|` in inline code inside a Markdown table cell gets a backslash. It split the cell, like a pipe in text.
- In html_mode a paragraph keeps its `<p>` inside a table cell too. Without it a paragraph ran into the text or the paragraph next to it.
- Text and block code written in html_mode have no blank line in them: the newline in front of a line that holds nothing is written as `&#10;`, which the HTML parser reads back as a newline. A blank line ended the HTML block, and what followed was Markdown again (`~~~` in a cell opened a code fence).
- Emphasis around nothing visible and an empty quote are written as nothing in html_mode too, as in Markdown. They were `<strong></strong>` and `<blockquote></blockquote>` before.
- A spoiler in html_mode is `<span class="spoiler">…</span>`, the form Discourse cooks the BBCode to, instead of `<details><summary>Spoiler</summary>…</details>`: a `<details>` is a block, and an HTML parser moves it out of the link or the emphasis around it. The title has no place in the span. A spoiler around nothing visible keeps no tags, in Markdown as well.
- `SuperscriptTag`, `SubscriptTag`, `ColorTag` and `SizeTag` return inline tokens with the HTML tags as `html` tokens, like the emphasis tags, so the serializer sees the tags as neighbors. A line break or a text that starts with a newline right after one of these opening tags is written as `<br>`: `<sup>` alone on its line opened an HTML block, and the rest of the superscript was raw text. A custom tag that calls `tag.render` on one of them gets an Array now.
- `LineBreakTag` returns a hard break token. The serializer writes it as a newline, as `<br>` when the line it ends holds nothing else (a second newline would be a blank line, which ends the paragraph and makes a list loose), and as nothing after a blank line. Two line breaks in a row gave a blank line before.
- Spaces at the start of a paragraph, and at the start of text after a blank line, are dropped. After a list they made the paragraph part of the last item.
- A nested list after a line that opens an HTML block of its own, like the `</div>` of an aligned block, gets no blank line in front any more. The line gets an empty comment in front instead (`<!----></div>`), which ends the block on that line, and the outer list stays tight. The `</table>` of a table still needs the blank line.
- Whitespace after an HTML tag name is read like markdown-it reads it, which includes the no-break space and the other Unicode spaces: `<style` followed by a no-break space gets a backslash, as it opens an HTML block in markdown-it.
- A text that starts with a newline right after a hard line break gets `<br>` for that newline: `x\n<br>y`. The two newlines were a blank line, which ended the paragraph and made a list loose.
- A mention right after anything but whitespace gets the `<!---->` boundary comment in front: `v<!---->@alice.i`. Without it, linkify read `v@alice.i` as an email address.
- A line break written as `<br>` at the end of a block goes again: it protected the line against the newline of the next piece, and nothing follows.
- `RenderingInterface` has `previous_sibling(element)`, `next_sibling(element)` and `sibling(element, offset:)`. For the element the renderer is rendering right now they look at the children of its parent, also when that parent has no tag of its own. For any other element they look at the children of the element on top of the parent chain, or of `RenderContext#root` when the chain is empty. `previous_list(element)` returns the last list in front of the element with nothing visible between them.

## Upgrading to 0.4.2

Check output assertions for aligned blocks and nested lists:

- Aligned content has blank lines inside its `<div>` so links and formatting render as Markdown. In an HTML table, alignment uses HTML content without those blank lines.
- List continuation lines use the width of their parent marker: two spaces for `- ` and three for `1. `. Nested items receive indentation from their parent item.

If your extensions use these helpers, update them:

| API | Action |
|---|---|
| `HtmlBlockSafety` | Rename references to `Markbridge::Renderers::Discourse::HtmlBlock`. |
| `ListItemBuilder#build` | Remove the `indent:` keyword. The builder indents continuation lines using the marker width. |

`HtmlBlock.safe?(output)` checks HTML-mode output. `HtmlBlock.island(markdown)` wraps Markdown in blank lines, and `HtmlBlock.opens?(line)` checks whether a line opens a CommonMark HTML block.

`render_children` accepts a block with the output buffer and the child about to be appended. Use it when your custom tag needs to adjust spacing between children:

```rb
interface.render_children(element, context:) do |buffer, child|
  buffer.rstrip! if child.is_a?(Markbridge::AST::List)
end
```

## Upgrading to 0.4.1

Lines containing only `=` characters are escaped, including lines at the start of a text node. This keeps a separator after a line break or inline element from becoming a heading. Update assertions that compare raw Markdown; the rendered equals signs remain visible.

## Upgrading to 0.4.0

### Review your AST subclasses

Normalizer rules, tag dispatch, and `interface.render_default` match class ancestry. A subclass without its own registration inherits the behavior of its nearest matching base class.

If you want a subclass to render only its children, register `Tag::PASSTHROUGH` for it. Removing its tag with `unregister:` allows an ancestor tag to apply. See [AST subclasses](/customization/extending/#ast-subclasses).

If you call `Normalizer::RuleSet#resolve` directly, pass a third argument: a Hash used as a cache for that tree walk. The public `normalize`, `violations`, and `rule` methods keep their signatures.

### Check code block output

BBCode `[code]` and `[pre]`, HTML `<pre>`, TextFormatter `<CODE>`, and MediaWiki indented and `<pre>` blocks render as fenced blocks even for one line. Language hints stay on the fence.

```ruby
require "markbridge/bbcode"

Markbridge.bbcode_to_markdown("[code=ruby]puts 1[/code]").markdown
# => "```ruby\nputs 1\n```"
```

When you build nodes yourself, set `AST::Code.new(block: true)` to force a block. Inline forms such as `[tt]` and `<code>` stay inline unless they contain a newline.

### Check HTML and empty elements

- HTML `<h1>` through `<h6>` render as headings.
- HTML code language detection checks `language-*` classes before `lang`, then a single class name. See [Code languages](/format-guides/html/#code-languages).
- Empty code, details, and spoiler elements produce no output.

Use the [shared HTML-mode example](/customization/extending/#rendering-inside-html-blocks) to check your custom tags.

## Upgrading to 0.3.1

A new `Markbridge::Normalizer` pass runs between the parse-time `yield` hook and rendering, and it's **on by default** for every `*_to_markdown` call, `convert`, and `render`. It rewrites nesting that Markdown can't express, so you may see different output with no code change on your side:

- A link inside a link collapses to a single link (CommonMark forbids nested links).
- A block element inside an inline container — a quote, list, table, or a `Poll`/`Event` inside a link, bold, or a heading — is moved out, so the inline element doesn't break.
- A fenced or multi-line code block inside an inline container is moved out; a one-line code span stays.
- A formatting wrapper left empty by the above is removed (no stray `**` `**`).

Every change is reported under `conversion.diagnostics[:normalization]`, next to `unknown_tags`. The default rules are legality only — Discourse policy like moving an image out of a link isn't built in; add those rules yourself. To turn the pass off, pass `normalize: false`. See [AST normalization](/concepts/normalization/) for the full picture.

## 0.3.0 — breaking changes

### `AST::Quote` attribution fields renamed and typed

`post` and `topic` are gone. The fields now say what they hold, and every id is an `Integer` (it used to be a `String`):

```rb
# Before
quote.post    # => "123"  (called "post ID", but actually a post *number*)
quote.topic   # => "456"

# After
quote.post_number  # => 123   position within the topic (Discourse quotes)
quote.topic_id     # => 456
quote.post_id      # => 9001  database id (phpBB / XenForo-style sources)
quote.user_id      # => 12    new — id-based user attribution
```

The TextFormatter parser no longer funnels phpBB's `post_id` into a rendered `post:N` attribution — a database id there links the wrong post. Id-attributed quotes now render name-only (`[quote="alice"]`) and carry `post_id` / `user_id` on the AST for you to remap, typically in the block yielded between parse and render.

### Bare and relative URLs render differently

- A **bare URL** — link text equal to the href, or no text — renders as the plain href instead of `[url](url)`, so Discourse can autolink and onebox it. `AST::Url#bare?` exposes the same judgment.
- **Relative hrefs** (`/t/5`, `#anchor`, wiki page names) are kept as links instead of being dropped. Unknown schemes (`javascript:` and friends) are still removed. Destinations containing whitespace use the `<…>` CommonMark form.
- A text-less link no longer renders as `[](url)`.

### Custom tags must return a String

A tag that returns `nil` (or anything other than a String) now raises a descriptive `TypeError` right away, instead of failing later inside string concatenation. To override only some nodes and keep the stock rendering for the rest, use the new fall-through:

```ruby
Markbridge::Renderers::Discourse::Tag.new do |node, interface|
  next interface.render_default(node) unless node.href&.start_with?("/")
  "[internal|#{node.href}]"
end
```

`interface.render_default(node)` renders the node with its stock Tag, bypassing your override — so a custom Tag can intercept just the cases it cares about and defer the rest.

## 0.2.0 — breaking changes

0.2.0 reshapes the top-level API around `Conversion`/`Parse` result types and a single `renderer:` kwarg for render-side customization. There is no backwards-compatibility shim — the changes are mechanical, but every call site needs to be updated.

### Convenience methods now return a `Conversion`, not a `String`

```rb
# Before
markdown = Markbridge.bbcode_to_markdown(input)
markdown.gsub(/.../, "...")           # String operation

# After
result = Markbridge.bbcode_to_markdown(input)
result.markdown.gsub(/.../, "...")    # explicit access

# Or, if you only need the string for puts/interpolation:
puts result                           # to_s delegates to markdown
"got #{result}"                       # works
```

`Conversion` carries `markdown`, `ast`, `format`, `unknown_tags`, `diagnostics`, `errors`. It does *not* delegate other String methods — `result.gsub(...)` raises `NoMethodError`. Use `result.markdown.gsub(...)`.

### Singleton config and per-process default registries are gone

Removed:

- `Markbridge.configuration`
- `Markbridge.configure { |c| c.escape_hard_line_breaks = ... }`
- `Markbridge.reset_defaults!`
- `Markbridge.default_handlers`
- `Markbridge.default_html_handlers`
- `Markbridge.default_text_formatter_handlers`
- `Markbridge.default_tag_library`
- `Markbridge::Configuration` (the class)

To customize rendering, build a `Renderer` once via the new factory and pass it through `renderer:`:

```rb
# Before
Markbridge.configure { |c| c.escape_hard_line_breaks = true }
Markbridge.default_tag_library.register(MyAst::Bold, MyTag.new)
Markbridge.bbcode_to_markdown(input)

# After
RENDERER =
  Markbridge.discourse_renderer(
    tags: { MyAst::Bold => MyTag.new },
    escape_hard_line_breaks: true,
  )
Markbridge.bbcode_to_markdown(input, renderer: RENDERER)
```

Build the renderer once outside your migration loop and reuse it across thousands of posts; it holds no per-post state. See [Customizing the renderer](/customization/customizing-renderer/) for the full set of factory kwargs.

### `tags:`, `tag_library:`, `escaper:`, `escape_hard_line_breaks:` removed from per-call signature

All four moved into `Markbridge.discourse_renderer(...)`. The four `*_to_markdown` methods plus `Markbridge.convert` now accept only:

- `handlers:` — parser handler registry
- `renderer:` — pre-built Renderer
- `raise_on_error:` — boolean (default `true`)

### MediaWiki kwarg renamed: `inline_tag_registry:` → `handlers:`

```rb
# Before
Markbridge.parse_mediawiki(input, inline_tag_registry: my_registry)
Markbridge::Parsers::MediaWiki::Parser.new(inline_tag_registry: my_registry)

# After
Markbridge.parse_mediawiki(input, handlers: my_registry)
Markbridge::Parsers::MediaWiki::Parser.new(handlers: my_registry)
```

The accepted *type* is unchanged — still an `InlineTagRegistry`. Only the parameter name moves, for parity with the BBCode/HTML/TextFormatter parsers.

### TextFormatter handlers must accept `processor:`

`Parsers::TextFormatter::Handlers::BaseHandler#process` now has a three-arg signature:

```rb
# Before
def process(element:, parent:)

# After
def process(element:, parent:, processor: nil)
```

Update every custom subclass under your importer's TextFormatter handler tree. The `processor:` argument is the parser instance and exposes `process_children(xml_element, ast_node)` for handlers that recurse into children manually.

Proc/lambda handlers are no longer accepted — a handler must be an object responding to `#process(...)`. Wrap any one-off lambda in a small handler class with a `#process` method.

### Tag side-data: read it back off the AST instead of mutating ctor-injected hashes

Placeholder Tags used to record side data by mutating a hash injected through the constructor (and a short-lived draft used an `interface.emit` buffer). Both are gone. A Tag is now a pure function of its element — it returns a string and records nothing; the importer collects side data by walking `conversion.ast` afterwards:

```ruby
# Before
class UrlTag < Markbridge::Renderers::Discourse::Tag
  def initialize(placeholders:)
    @placeholders = placeholders
  end

  def render(element, _interface)
    link = build_link(element)
    @placeholders[:links] << link        # mutates ctor-injected array
    link[:placeholder]
  end
end
# Importer pre-allocates @placeholders, passes to Tag, reads it after.

# After
class UrlTag < Markbridge::Renderers::Discourse::Tag
  def render(element, _interface)
    build_link(element)[:placeholder]    # pure: returns a string, records nothing
  end
end
# Importer reads back: result.ast.descendants(InternalLink).each { |node| ... }
```

The resolved value the importer needs lives on the custom AST node (pinned at parse time by the handler, or read off the source-side data the Tag already has). Pure lookup tables (`uploads:`, `repository:`) injected into Tag constructors are still fine — they're read-only. Only *mutation during render* moves out, to a walk over `conversion.ast.descendants(...)`. See [Placeholders](/migrating/placeholders/).

### `RawHandler` no longer requires `language:` on the AST class

`Markbridge::Parsers::BBCode::Handlers::RawHandler` used to call `@element_class.new(language:)` unconditionally. Custom AST classes reused with `RawHandler` had to declare a `language:` kwarg even when unused. The handler now introspects the AST class once and only passes `language:` when the class accepts it. No code action needed unless you'd previously added a dummy `def initialize(language: nil); super(); end` just to satisfy the handler — you can remove it.

### Per-row failure isolation

For migration loops, set `raise_on_error: false` to surface render exceptions on `Conversion#errors` instead of crashing the loop:

<!-- spec:before
RENDERER = Markbridge.discourse_renderer
def log_failure(_post, _errors); end
def write_markdown(_post, _markdown); end
posts = [Struct.new(:body).new("[b]hi[/b]")]
-->
```ruby
posts.each do |post|
  result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER, raise_on_error: false)
  if result.errors.any?
    log_failure(post, result.errors)
  else
    write_markdown(post, result.markdown)
  end
end
```

The default remains `raise_on_error: true`, preserving the prior behavior of letting exceptions propagate.

## 0.2.0 — new capabilities

0.2.0 also added a few things you'll likely want during a migration.

### Let some Markdown markers through with `allow:`

If your source posts already contain `- item` or `1. item` lists you want to keep, you no longer need to subclass the escaper. Before, you'd write a whole class:

```ruby
class ListPermissiveEscaper < Markbridge::Renderers::Discourse::MarkdownEscaper
  private

  def escape_block_level(content, prev_was_paragraph)
    case content.getbyte(0)
    when 0x2D, 0x2A, 0x2B then return content, false if content.match?(/\A[-*+]\s/)
    when 0x30..0x39       then return content, false if content.match?(/\A\d+[.)]\s/)
    end
    super
  end
end
Markbridge.discourse_renderer(escaper: ListPermissiveEscaper.new)
```

Now it's one keyword:

```ruby
Markbridge.discourse_renderer(allow: :lists)
```

The keys are `:bullet_list`, `:ordered_list`, `:atx_heading`, and `:block_quote`, plus the alias `:lists` (bullet + ordered). An unknown key raises `ArgumentError`. Thematic breaks (`---`, `***`) and setext underlines (`===`) are still escaped — `allow:` opens up specific markers, not the whole escaper.

### Turn escaping off completely with `escape: false`

When the source is already trusted Markdown, skip escaping entirely:

<!-- spec:before
input = "already **trusted** markdown"
-->
```ruby
no_escape = Markbridge.discourse_renderer(escape: false)
Markbridge.bbcode_to_markdown(input, renderer: no_escape)
```

This swaps in `Markbridge::Renderers::Discourse::IdentityEscaper`, a tiny class whose `escape` returns the text unchanged. `escape: false` can't be combined with `escape_hard_line_breaks:` or `allow:` (those configure the normal escaper, which `escape: false` replaces). An explicit `escaper:` always wins. For a single node rather than the whole document, `AST::MarkdownText` already skips the escaper for that node only.

### Change the AST between parse and render

You can edit the parsed tree before it's rendered — handy for adding attachments that weren't in the post body. Every `*_to_markdown` / `convert` method takes a block, or you can render a `Parse` by hand:

<!-- spec:before
class OrphanAttachment < Markbridge::AST::Node
  attr_reader :source_id
  def initialize(source_id:)
    super()
    @source_id = source_id
  end
end
class OrphanAttachmentTag < Markbridge::Renderers::Discourse::Tag
  def render(element, _interface) = "[upload|#{element.source_id}]"
end
RENDERER = Markbridge.discourse_renderer(tags: { OrphanAttachment => OrphanAttachmentTag.new })
input = "see attached"
attachments = [Struct.new(:id).new(42)]
-->
```ruby
# Block form — edit the AST inline
Markbridge.bbcode_to_markdown(input, renderer: RENDERER) do |ast|
  attachments.each { |a| ast << OrphanAttachment.new(source_id: a.id) }
end

# Or render a Parse you've already changed
parse = Markbridge.parse_bbcode(input)
parse.ast << OrphanAttachment.new(source_id: 7)
result = Markbridge.render(parse, renderer: RENDERER)
```

`Markbridge.render` takes either a `Parse` (preferred — it keeps `unknown_tags`, `diagnostics`, and the source `format`) or a bare AST node (those fields default to empty, and `format` is `nil` since there was no source). A non-`Document` node is wrapped in one, so `Conversion#ast` is always a `Document`. Your changes stay in `Conversion#ast`.

### Pass a Nokogiri tree to the HTML and TextFormatter parsers

Both Nokogiri-backed parsers now accept a `String` *or* a parsed Nokogiri node. If your importer already runs its own DOM pass, hand the live tree straight over — no serialize-and-reparse in between:

<!-- spec:before
html = "<p>hello <b>world</b></p>"
-->
```ruby
fragment = Nokogiri::HTML.fragment(html)
Markbridge.html_to_markdown(fragment)
```

Same idea for TextFormatter XML:

<!-- spec:before
xml = "<r>hello</r>"
-->
```ruby
xml_doc = Nokogiri.XML(xml)
Markbridge.text_formatter_xml_to_markdown(xml_doc)
```

A full `Nokogiri::HTML::Document` is unwrapped to its `<body>` children (so the synthetic `<html>`/`<head>`/`<body>` don't show up in `unknown_tags`); a fragment or bare element iterates its own children. For TextFormatter, an XML `Document` is unwrapped via `#root` (the single `<r>`/`<t>` element). Skipping the round-trip also avoids a quirk where re-serializing percent-encodes non-ASCII bytes in URLs.

### Walk and edit the tree with helpers on `Element`

Three methods replace the hand-rolled recursion importers used to write:

<!-- spec:before
doc = Markbridge::AST::Document.new
doc << Markbridge::AST::Bold.new.tap { |b| b << Markbridge::AST::Text.new("hi") }
-->
```ruby
# Walk every descendant, depth-first
doc.each_descendant { |node| node }

# Filter by class (uses is_a?, so abstract bases match subclasses)
bold = doc.descendants(Markbridge::AST::Bold).first

# Swap a direct child in place, keeping its position
doc.replace_child(bold, Markbridge::AST::Text.new("HI"))
```

`each_descendant` snapshots each element's children when it reaches them, so calling `replace_child` mid-walk is safe and nodes appended during the walk aren't re-visited.

### `AST::Details` for collapsible sections

Discourse's collapsible `[details=…]…[/details]` block is now a built-in AST node with an auto-registered Tag, so you can drop any local `DetailsBlock` shim:

<!-- spec:before
doc = Markbridge::AST::Document.new
-->
```ruby
doc << Markbridge::AST::Details.new(title: "Signature").tap do |block|
  block << Markbridge::AST::Text.new("--\nAlex Doe")
end
Markbridge.render(doc).markdown
```

`title` is optional — leave it out for a bare `[details]` (and `<summary>Summary</summary>` in HTML mode). The title is HTML-escaped in the `<summary>`.

## See also

- [Customizing the renderer](/customization/customizing-renderer/) — full reference for the factory.
- [Extending Markbridge](/customization/extending/) — adding custom tags and handlers.
