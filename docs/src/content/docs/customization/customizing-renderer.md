---
title: Customizing the renderer
description: The options of Markbridge.discourse_renderer — your own tags, the plugins of the target site, relative links, escaping, and cleanup.
---

The default renderer writes Markdown for a Discourse site with the default plugins. When your site or your content needs something else, build your own renderer with `Markbridge.discourse_renderer` and pass it to every conversion as `renderer:`.

<!-- spec:before
MyPlaceholderUrlTag = Class.new(Markbridge::Renderers::Discourse::Tag) do
  def render(element, interface) = interface.render_children(element)
end
def write_markdown(_post, _markdown); end
posts = [Struct.new(:body).new("[b]hi[/b]")]
-->
```ruby
RENDERER = Markbridge.discourse_renderer(
  tags: { Markbridge::AST::Url => MyPlaceholderUrlTag.new },
  unregister: [Markbridge::AST::Color, Markbridge::AST::Size],
  escape_hard_line_breaks: true,
)

posts.each do |post|
  result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER)
  write_markdown(post, result.markdown)
end
```

Build the renderer once and use it for all posts. It keeps nothing from one post to the next. It does keep state while a render call runs, so use one renderer per thread.

## The options

Which option for which problem:

| You want to | Option |
|---|---|
| Write a node your own way, or not at all | [`tags:`](#tags--override-or-add-tags), [`unregister:`](#unregister--drop-ast-classes) |
| Write what the plugins of your site can show | [`features:`](#features--the-plugins-of-the-target-site), with `sizes:` and `colors:` |
| Keep relative links and images working | [`base_url:`](#base_url--where-relative-addresses-point-to) |
| Keep Markdown that is already in the source | [`allow:`](#allow--let-specific-markdown-markers-through), [`escape:`](#escape--turn-escaping-off-entirely), [`escaper:`](#escaper--full-escaper-replacement) |
| Change the final cleanup | [`postprocessor:`](#postprocessor--clean-up-the-final-string) |

All of them, with their defaults:

```ruby
Markbridge.discourse_renderer(
  tags: nil,                         # Hash{Class => Tag, nil}
  tag_library: nil,                  # starting library
  unregister: nil,                   # Array<Class> to drop
  escaper: nil,                      # custom MarkdownEscaper
  escape_hard_line_breaks: false,    # sugar for the default escaper
  allow: nil,                        # Symbol/Array<Symbol> — markers to leave unescaped
  escape: true,                      # false swaps in IdentityEscaper (no escaping)
  postprocessor: nil,                # custom Postprocessor instance
  features: nil,                     # Hash{Symbol => Boolean} — the plugins of the target site
  sizes: nil,                        # with bbcode: true — the source's size values to percent
  colors: nil,                       # with bbcode: true — a mapping for the color values
  base_url: nil,                     # String — makes relative links and images absolute
)
```

Every option is optional. Without any you get the default renderer.

### `tags:` — override or add Tags

`tags:` is a Hash from an AST class to the `Tag` that writes it. Your entries are added to the default library, so every class you do not list keeps its default tag.

<!-- spec:before
MyBoldTag = MyPlaceholderUrlTag = Class.new(Markbridge::Renderers::Discourse::Tag) do
  def render(element, interface) = interface.render_children(element)
end
-->
```ruby
Markbridge.discourse_renderer(
  tags: {
    Markbridge::AST::Bold => MyBoldTag.new,
    Markbridge::AST::Url  => MyPlaceholderUrlTag.new,
  }
)
```

A class with `nil` as its tag is removed from the library, the same as listing it in `unregister:`. [Extending Markbridge](/customization/extending/) explains how to write a tag.

### `unregister:` — drop AST classes

A node without a tag is written as its children. So removing the tag of `AST::Color` drops the color and keeps the text, with all formatting inside it.

For a subclass this works differently: without a tag of its own, the tag of the nearest superclass writes it. To write only the children of a subclass, register `Tag::PASSTHROUGH` for it.

```ruby
Markbridge.discourse_renderer(
  unregister: [Markbridge::AST::Color, Markbridge::AST::Size, Markbridge::AST::Underline]
)
```

### `escape_hard_line_breaks:` — strip trailing-space line breaks

In Markdown, two or more spaces at the end of a line are a line break. Source text often has such spaces by accident, and they would become line breaks nobody wrote.

```ruby
Markbridge.discourse_renderer(escape_hard_line_breaks: true)
# "a  \nb" is written as "a\nb"
```

The default, `false`, keeps the spaces.

### `escaper:` — full escaper replacement

The escaper puts backslashes in front of the characters in source text that Markdown would read as markup. For full control pass your own, usually a subclass of `MarkdownEscaper`. With an `escaper:`, `escape_hard_line_breaks:` is ignored.

```ruby
class ListPermissiveEscaper < Markbridge::Renderers::Discourse::MarkdownEscaper
  # Keep a "- " at the start of a text, so lists typed as plain text stay lists.
  def escape(text, context: nil)
    return text if text.match?(/\A- /)
    super
  end
end

Markbridge.discourse_renderer(escaper: ListPermissiveEscaper.new)
```

### `allow:` — let specific Markdown markers through

A forum post that starts a line with `- ` or `1.` did not mean a list, so the escaper escapes these markers. Some sources do mean it: users typed Markdown lists into a forum that showed them as text. To keep such lists, allow the markers:

```ruby
Markbridge.discourse_renderer(allow: :lists)
```

The keys are `:bullet_list`, `:ordered_list`, `:atx_heading` and `:block_quote`. `:lists` stands for both list keys. An unknown key raises `ArgumentError`.

Everything else stays escaped, also horizontal rules (`---`, `***`) and the underline of a heading (`===`). `allow:` changes the default escaper, so it cannot be combined with your own `escaper:`.

### `escape:` — turn escaping off entirely

When the text of your source is Markdown already, turn escaping off:

```ruby
Markbridge.discourse_renderer(escape: false)
```

The renderer then uses `Markbridge::Renderers::Discourse::IdentityEscaper`, which returns text as it is. `escape: false` cannot be combined with `escape_hard_line_breaks:` or `allow:`, which are options of the default escaper. An `escaper:` you pass wins over all three.

To leave only one piece of text unescaped, put it into the tree as an `AST::MarkdownText` node.

### `features:` — the plugins of the target site

Some of what the renderer writes is BBCode that a Discourse plugin cooks. A site without the plugin shows that BBCode as text. `features:` says which plugins the site has, and the renderer writes a plain form where it has none:

| Feature | Plugin | Default | With the plugin | Without it |
|---|---|---|---|---|
| `details` | discourse-details, bundled with Discourse (`details_enabled`) | on | `[details="title"]…[/details]` | the title as a paragraph in bold, then the content |
| `spoiler` | spoiler-alert, bundled (`spoiler_enabled`) | on | `[spoiler]…[/spoiler]`, with the tags on lines of their own for a block spoiler | the content, so the hidden text shows |
| `poll` | poll, bundled (`poll_enabled`) | on | `[poll]…[/poll]` | the options as a bullet list |
| `post_event` | discourse-events, bundled (`discourse_post_event_enabled`) | on | `[event …][/event]` | a paragraph with the name and the dates |
| `bbcode` | [discourse-bbcode](https://github.com/discourse/discourse-bbcode), needs an install | undecided | `[color=…]…[/color]`, `[size=…]…[/size]` | the text |

```ruby
renderer = Markbridge.discourse_renderer(features: { post_event: false, bbcode: false })
```

Leave a bundled plugin on, even when your site has it turned off today. Discourse stores the Markdown and renders it again when a setting changes. The BBCode of a plugin that is off becomes a details block or a poll as soon as someone turns the plugin on. The plain form stays plain forever. Turn a feature off only for a site that will never use the plugin.

An unknown feature raises `ArgumentError`. A tag in `tags:` wins over `features:`. Underline (`[u]`), quotes with an author (`[quote="…"]`) and aligned blocks (`<div align>`) need no plugin, Discourse core cooks them.

#### Colors and sizes

Discourse shows colors and sizes only with the discourse-bbcode plugin, and the plugin accepts only some values. Markbridge cannot know whether your site has the plugin, and both guesses lose something: BBCode shows as text on a site without it, and plain text loses the colors on a site with it. So you have to decide. Until you do, the first color or size in a post raises `Markbridge::UndecidedFeatureError`. A source without colors and sizes never raises it.

- `features: { bbcode: false }` writes the text only.
- `features: { bbcode: true }` writes the BBCode and needs `sizes:`. The plugin reads `[size=…]` as a percentage, and every forum has its own scale, so `sizes:` maps the values of your source to a whole number from 1 to 999. A Hash is read with `fetch`, so a value it does not know raises `KeyError`; a lambda can do anything; `nil` drops the size on purpose. Any other result raises `ArgumentError`.
- `colors:` is optional and works the same way. A value the plugin would strip (not `#rgb`, `#rrggbb` or a name) raises `ArgumentError`, with or without a mapping.

phpBB 3.x already stores sizes in percent, so the identity is the mapping. vBulletin and XenForo use `[size=1]` to `[size=7]`, the scale of `<font size>`:

```ruby
FONT_SIZES = { "1" => 63, "2" => 81, "3" => 100, "4" => 113, "5" => 150, "6" => 200, "7" => 300 }

renderer = Markbridge.discourse_renderer(features: { bbcode: true }, sizes: FONT_SIZES)

Markbridge.bbcode_to_markdown("[color=red]a[/color] [size=5]b[/size]", renderer:).markdown
# => "[color=red]a[/color] [size=150]b[/size]"
```

Three things the renderer does on its own:

- A color over several paragraphs gets its tags in every paragraph, because the BBCode cannot go over a blank line.
- A color inside a link is written as its text. Discourse does not read BBCode in the text of a link.
- Inside a table that is written as HTML, the output is `<span style="color:red">` or `<span style="font-size:85%">`, the form the plugin allows.

### `base_url:` — where relative addresses point to

A post can link to `page.html`, `../files/a.pdf` or `/images/a.png`. On the source site these are addresses relative to the page they are on. In Discourse they do not work:

- Discourse drops an address without a scheme and without a leading slash. The link shows as text, the image not at all.
- An address with a leading slash points to the Discourse site, not to the site the post came from.

With `base_url:` the renderer makes relative addresses absolute, like a browser does on a page at that URL:

```ruby
renderer = Markbridge.discourse_renderer(base_url: "https://old.example.com/forum/")

html = '<a href="viewtopic.php?t=34">an older topic</a> <img src="/images/a.png" alt="a">'
Markbridge.html_to_markdown(html, renderer:).markdown
# => "[an older topic](https://old.example.com/forum/viewtopic.php?t=34) ![a](https://old.example.com/images/a.png)"
```

How addresses are resolved:

| In the source | With `base_url: "https://old.example.com/forum/index.php"` |
|---|---|
| `viewtopic.php?t=34` | `https://old.example.com/forum/viewtopic.php?t=34` |
| `../files/a.pdf` | `https://old.example.com/files/a.pdf` |
| `/images/a.png` | `https://old.example.com/images/a.png` |
| `?page=2` | `https://old.example.com/forum/index.php?page=2` |
| `https://example.org/`, `//cdn.example.org/a.png`, `mailto:a@example.org`, `#top` | unchanged |

The last part of the base URL is a page, and relative addresses are next to it. End the base URL with a slash when it names a directory. A `base_url:` that is no http or https URL raises `ArgumentError`.

The option applies to links and images. A tag you pass in `tags:` for `AST::Url` or `AST::Image` replaces it for that class.

### `postprocessor:` — clean up the final string

The tags write blank lines around their blocks, so the joined output has too many. A `Postprocessor` cleans up at the end: it turns several blank lines into one, empties lines with only whitespace, and removes whitespace at the start and the end. To add a step of your own, subclass it and override `#call`:

```ruby
class StripDoubleSpaces < Markbridge::Renderers::Discourse::Postprocessor
  def call(text)
    super.gsub(/(?<=\S)  +(?=\S)/, " ")
  end
end

Markbridge.discourse_renderer(postprocessor: StripDoubleSpaces.new)
```

`->(text) { text }` as the postprocessor gives you the output without any cleanup.

## Build once, use for every post

Building a renderer takes about as long as converting a short post. Built for every post, it would add half of the work again for nothing. Build it once, for example in a constant:

```ruby
class ForumImporter
  RENDERER = Markbridge.discourse_renderer(
    tags: {},          # your custom Tags
    unregister: [],    # AST classes to drop
    escape_hard_line_breaks: true,
  )

  def import(post)
    result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER)
    persist(post, result.markdown)
  end
end
```

A call without `renderer:` costs nothing extra: it uses the default tag library, which is built once per process.

## See also

- [Extending Markbridge](/customization/extending/) — how to write the tags and handlers you register here.
- [Migrating to Discourse](/migrating/overview/) — these options in an importer.
- [Upgrading](/reference/upgrading/) — what changed between versions.
