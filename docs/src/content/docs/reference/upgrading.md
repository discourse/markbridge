---
title: Upgrading
description: Breaking-change notes between Markbridge releases.
---

## Upgrading to 0.5.1

Most projects update without a change to their code. What changes is the output for some input, and a few nodes of the AST. Look at the group of the format you convert.

### New options and nodes

- **`base_url:` for relative links and images.** `Markbridge.discourse_renderer(base_url: "https://old.example.com/forum/")` makes relative addresses absolute. Discourse drops an address without a scheme and without a leading slash, so without it such links show as text. See [Customizing the renderer](/customization/customizing-renderer/#base_url--where-relative-addresses-point-to).
- **`<ins>`, `<del>` and `<mark>`.** The HTML and MediaWiki parsers read them into the new nodes `AST::Insertion`, `AST::Deletion` and `AST::Highlight`, and the renderer writes the HTML tags, which Discourse keeps. Before, `<del>` was strikethrough (`~~…~~`), `<ins>` in wikitext was underline (`[u]…[/u]`), and HTML dropped `<ins>` and `<mark>`. `[del]` in BBCode is still strikethrough.
- **`colspan` and `rowspan`.** `AST::TableCell` has the two as keywords, all four parsers read them, and a table with such a cell is written as an HTML table with the attributes, which Discourse keeps. Before, the spans were lost and the cells stood in the wrong columns.

### BBCode

- **Unquoted BBCode options with spaces.** `[quote=John Doe]` quotes "John Doe", not "John"; `[url=https://example.com/a b]` keeps the whole address; `[spoiler=What went wrong]` is a spoiler with that title and no longer text. The option ends at the `]` or at the first `name=`.
- **A tag that is never closed in a BBCode list item** ends with the item. `[list][*]one [b]bold[*]two[/list]` has two items now. Before, the second item was nested in the bold of the first and the `[/list]` showed as text. The same goes for a tag that is still open when the list ends.
- **The line break right after a code tag** is not a first, empty line of the code anymore: `[code]`, `[pre]`, HTML `<pre>` and `<pre>` in wikitext drop one line break after the tag. HTML itself says so for `<pre>`. A second line break stays, and so does one after `[tt]` or `<code>`.

### HTML

- **`thead`, `tbody` and `tfoot`** are no longer in `unknown_tags` of the HTML parser. The set is `HandlerRegistry#transparent_tags`, add the wrappers you expect.

### MediaWiki

- **MediaWiki page links.** The href of `[[Page title]]` is `./Page_title` now, relative to the wiki and with underscores for spaces, like MediaWiki's own HTML has it. It was the title as written. `[[Alta Via]]` renders as `[Alta Via](./Alta_Via)`, before it was plain text; `[[Help:Contents|help]]` keeps its link. Pass the address of the wiki as `base_url:` to make them full URLs. If you map page titles to URLs on the AST, look for hrefs that start with `./`. See the [MediaWiki guide](/format-guides/mediawiki/#links-to-wiki-pages).
- **Files and categories in wikitext.** `[[File:Name.jpg|thumb|Caption]]` is an image with the caption as its alternative text, at `./Special:FilePath/Name.jpg`; with `base_url:` that is the file on the wiki. A file that is no image is a link to its page. `[[Category:Name]]` shows nothing. Before, both were links with the options in their text.
- **The caption of a wikitext table** (`|+ text`) is a paragraph in front of the table. It was a cell of the first row.
- **Bold inside italic in wikitext.** `''italic and '''bold''' in it''` is italic with bold in it. The three apostrophes ended the italic before.
- **`<nowiki>` over several lines** in wikitext is one piece of literal text. Before, the tags showed as text and the lines were parsed.
- **HTML-like tags in wikitext** are read in any case: `<S>` like `<s>`.
- **`[[]]` in wikitext** is text. The MediaWiki parser raised `NoMethodError` for it.

### s9e\TextFormatter XML

- **Litedown elements in s9e XML.** `<STRONG>`, `<EM>`, `<DEL>`, `<SUP>`, `<SUB>`, `<C>` and `<H1>` to `<H6>` are read, which is what a Flarum post is made of. They were unknown tags, so their formatting was lost.
- **Spoilers in s9e XML.** `<SPOILER>` is a block spoiler now: `AST::Spoiler` has a `block:` keyword, and the renderer writes `[spoiler]` and `[/spoiler]` on lines of their own, with a title as a paragraph in front (`Title:`). Before, the spoiler was written inside the line and the text after it was glued to it. `<ISPOILER>` is read as an inline spoiler. A block spoiler inside bold or a link is moved out by the normalizer.
- **`<HR>`** is a horizontal rule. It was counted as an unknown tag and dropped.
- **More elements of s9e XML.** `<CENTER>`, `<LEFT>`, `<RIGHT>` and `<JUSTIFY>` are aligned blocks. `<ESC>`, `<E>` and `<EMOJI>` are passed through and no longer counted in `unknown_tags`; the set is `HandlerRegistry#transparent_tags` of the TextFormatter parser.
- **The space after a code span at the start of a line** in s9e XML is kept.

### Normalizer and renderer

- **Text around a block that was moved out.** When the normalizer moves a block out of bold, a link or another inline container, the texts on its two sides get a space between them when they would touch.
- **A URL right in front of a closing `~~` or a closing BBCode tag.** Discourse takes `~~`, `[/u]`, `[/color]`, `[/size]` and `[/spoiler]` into a URL that stands right in front of them, so the link was wrong and the closing tag showed as text. A link whose text is its URL is written as `[url](url)` there, and a URL in plain text gets an empty comment after it: `~~see https://example.com/a<!---->~~`.
- **A `<` in front of a scheme at the end of a text** gets a backslash, `\<mailto:`. With a link right after it the two cooked as one broken autolink.
- **An image with only a width** is written without a size, `![alt](src)`. Discourse reads a size only as `WIDTHxHEIGHT`, so the `100` of `![alt|100](src)` stayed in the alt text.
- **Blockquotes.** Two blocks in a `>` quote have one `>` line between them, not three.
- **A paragraph with an upload in a table written as HTML** is a `<div>`, not a `<p>`. A `<p>` ends at the `<div>` of the upload, and an inline element around the upload, a `<del>` for example, stayed behind empty.
- **An empty paragraph in a table written as HTML** is nothing. It was an empty `<p></p>`, which kept a list item around it alive.
- **The normalizer report** names a node of a class without a name (from `Class.new`) after its nearest named ancestor. It raised `NoMethodError`.

### Removed

- The BBCode list item alias `[.]` and the TextFormatter element `*`. No input reached either of them.

## Upgrading to 0.5.0

The round-trip specs (see the Testing section of AGENTS.md) found a number of output defects. The fixes change the Markdown for the cases below, so check output assertions that cover them:

- A fenced code block whose content ends with a newline no longer gets a blank line before the closing fence. `<pre><code>x\n</code></pre>` and `[code]x\n[/code]` render as ` ```\nx\n``` `.
- The postprocessor leaves fenced code blocks alone. Blank lines and whitespace-only lines inside a fence stay as they are.
- Inline code picks a backtick delimiter longer than any backtick run in the content, and pads the content with a space when it starts or ends with a backtick or with spaces on both sides: `` `a`b` `` becomes ``` ``a`b`` ```.
- Images carry their alternative text. `AST::Image` has a new `alt:` keyword, the HTML, BBCode and TextFormatter parsers fill it, and the renderer writes `![alt|WxH](src)` in Markdown and `alt="…"` in html_mode. Line breaks in the alt text become spaces. Discourse reads the `|` parts at the end of the alt text as image options (a size, `video`, `audio`, `thumbnail`, `key=value`). When the alt text itself ends in such a part, an empty part follows it, `![screenshot\|800x600|](a.png)`, so Discourse does not resize the image; the alt text gets a `|` at its end.
- Parentheses and backslashes in a link or image destination are escaped: `[text](https://example.com/a\(b\))`. An image destination with whitespace is wrapped in `<…>`, like a link destination already was.
- A run of `#` at the end of a heading gets a backslash, so it stays visible: `### foo \###`. This also applies to a heading that is nothing but `#` characters.
- A horizontal rule inside a list item is written as `* * *`. As `---` it ended the list when it was the first thing in the item.
- A `!` directly in front of a link gets a backslash, so `Look![here](url)` does not cook as an image.
- Two lists of the same kind that follow each other are written with different markers, `- a` then `* b`, or `1. a` then `1) b`, so they do not merge into one loose list; a third list goes back to the first marker. Whitespace, line breaks and anything that renders to nothing between the two lists do not count as something between them. A list without items renders to nothing. A horizontal rule inside a list written with `*` is `- - -`, so it is not read as the rule alone.
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
- Two lists of the same kind directly inside a list item get different markers as well, without a blank line between them, so the outer list stays tight.
- A table with a block in a cell (a list, a quote, a heading, a rule, a code block, a details or aligned block) is written as an HTML table. As a Markdown table the cell showed the block's markers as text. A table whose header row is not its first row is an HTML table too, and keeps its rows in order; the Markdown form moved the header row to the top. In an HTML table the header rows at the top go into `<thead>`, every other row into `<tbody>` in order.
- A table inside a table has no blank lines around it. Inside the outer table's HTML block a blank line ended the block, and the rest was Markdown again.
- A `|` in inline code inside a Markdown table cell gets a backslash. It split the cell, like a pipe in text.
- In html_mode a paragraph keeps its `<p>` inside a table cell too. Without it a paragraph ran into the text or the paragraph next to it.
- Text and block code written in html_mode have no blank line in them: the newline in front of a line that holds nothing is written as `&#10;`, which the HTML parser reads back as a newline. A blank line ended the HTML block, and what followed was Markdown again (`~~~` in a cell opened a code fence).
- Emphasis around nothing visible is written as nothing in html_mode too, as in Markdown, and so is an empty quote. They were `<strong></strong>` and `<blockquote></blockquote>` before.
- A spoiler in html_mode is `<span class="spoiler">…</span>`, the form Discourse cooks the BBCode to, instead of `<details><summary>Spoiler</summary>…</details>`: a `<details>` is a block, and an HTML parser moves it out of the link or the emphasis around it. The title has no place in the span. A spoiler around nothing visible keeps no tags, in Markdown as well.
- `SuperscriptTag` and `SubscriptTag` return inline tokens with the HTML tags as `html` tokens, like the emphasis tags, so the serializer sees the tags as neighbors. A line break or a text that starts with a newline right after one of these opening tags is written as `<br>`: `<sup>` alone on its line opened an HTML block, and the rest of the superscript was raw text. A custom tag that calls `tag.render` on one of them gets an Array now.
- `LineBreakTag` returns a hard break token. The serializer writes it as a newline, as `<br>` when the line it ends holds nothing else (a second newline would be a blank line, which ends the paragraph and makes a list loose), and as nothing after a blank line. Two line breaks in a row gave a blank line before.
- Spaces at the start of a paragraph, and at the start of text after a blank line, are dropped. After a list they made the paragraph part of the last item.
- A nested list after a line that opens an HTML block of its own, like the `</div>` of an aligned block, gets no blank line in front any more. The line gets an empty comment in front instead (`<!----></div>`), which ends the block on that line, and the outer list stays tight. The `</table>` of a table still needs the blank line.
- Whitespace after an HTML tag name is read like markdown-it reads it, which includes the no-break space and the other Unicode spaces: `<style` followed by a no-break space gets a backslash, as it opens an HTML block in markdown-it.
- A text that starts with a newline right after a hard line break gets `<br>` for that newline: `x\n<br>y`. The two newlines were a blank line, which ended the paragraph and made a list loose.
- A mention right after anything but whitespace gets the `<!---->` boundary comment in front: `v<!---->@alice.i`. Without it, linkify read `v@alice.i` as an email address.
- A line break written as `<br>` at the end of a block goes again: it protected the line against the newline of the next piece, and nothing follows.
- The TextFormatter parser treats whitespace like phpBB shows it. The newline after `<br/>` and spaces at the start of a line are removed outside of `<CODE>`, so `a<br/>\nb` renders as `a\nb` instead of `a\n\nb`. Two `<br/>` in a row are an empty line in phpBB and become a blank line in the text (`a\n\nb`), not two `AST::LineBreak` nodes, so they stay a paragraph break. A space between two inline elements is kept: `<B>a</B> <I>b</I>` renders as `**a** *b*`.
- Colors and sizes render as their text only. They were `<span style="color: …">` and `<span style="font-size: …px">`, and Discourse removed that style, also with the discourse-bbcode plugin, which only accepts `color:…` without a space and sizes in percent. `Markbridge.discourse_renderer(features: { bbcode: true })` writes `[color=…]…[/color]` and `[size=…]…[/size]` for that plugin instead, with every paragraph in its own tags. Without BBCode `ColorTag` and `SizeTag` return their text as inline tokens, so a custom tag that calls `tag.render` on one of them gets an Array; with BBCode they return a String.
- A quote without attribution that contains a quote with an author or username renders as `[quote]\n…\n[/quote]` instead of a `> ` blockquote, for all parsers. Discourse doesn't render a `[quote="…"]` inside a Markdown blockquote, so it showed up as text. Other quotes without attribution stay blockquotes, and an empty one still renders to nothing.
- A quote no longer starts or ends with blank lines when its content starts or ends with a block. `[quote][list][*]a[/list][/quote]` renders as `> - a` instead of `> \n> \n> - a`, and `[quote=A][quote=B]x[/quote][/quote]` has no blank line after `[quote="A"]`.
- The TextFormatter parser skips `<i>` (lowercase), the text s9e ignored. It rendered as italic before.
- The TextFormatter `AttachmentHandler` and `ImageHandler` return `nil`, so the fallback text in their content is skipped. An `<ATTACHMENT>` with content raised `NoMethodError` before, and an `AST::Image` no longer gets the URL as a child.
- Bold, italic, strikethrough and underline whose content has a blank line in it are closed before the blank line and opened again after it, for all parsers: `[b]a\n\nb[/b]` renders as `**a**\n\n**b**`. A blank line ended the paragraph, so the markers stayed visible as text. Content with a code fence is not split. `Markbridge::Renderers::Discourse::Paragraphs.map` does the split and can be used by custom tags.
- `Markbridge.discourse_renderer` takes `features:`, a Hash that says which plugins the target site has: `details`, `spoiler`, `poll` and `post_event` (bundled with Discourse, on by default) and `bbcode` (discourse-bbcode). With a feature off the renderer writes a plain form instead of the plugin's BBCode: the title in bold and the content for a details block, the content for a spoiler, the options as a bullet list for a poll, a paragraph with the name and the dates for an event. `DetailsTag`, `SpoilerTag`, `PollTag` and `EventTag` take `bbcode:` for the same thing. `Renderer#tag_library` returns the library a renderer renders with.
- A color or size raises `Markbridge::UndecidedFeatureError` until the renderer knows whether the site has discourse-bbcode: `features: { bbcode: false }` writes the text, `features: { bbcode: true }` the BBCode. The text was the default before, and a size or color was lost without a word. With `bbcode: true`, `sizes:` is required and maps the size values of the source forum to the percent the plugin reads (a Hash read with `fetch`, or a callable; `nil` drops a size); `colors:` is an optional mapping for the color values. A value the plugin does not accept raises `ArgumentError` instead of rendering as the text. `ColorTag` and `SizeTag` take `bbcode:` (`nil`, `true` or `false`) and the mapping. Inside a link, and without a value, the text is written in every case.
- The plain form of a details block without the plugin is a `<div>` in html_mode, so the block stays apart from the text next to it in a table cell.
- A spoiler inside a link is written as its text, like an underline there: Discourse doesn't cook BBCode in the text of a link, so `[[spoiler]x[/spoiler]](url)` showed the tags.
- A spoiler on the same line as an earlier spoiler gets the `<!---->` comment after it, with whitespace, text or inline elements between the two: `[spoiler]x[/spoiler] and [spoiler]y[/spoiler]<!---->`. A line that starts with `[spoiler]` and ends with `[/spoiler]` is one block spoiler to Discourse, whatever stands between, so the inner tags showed as text.
- A renderer is not safe to share between threads, use one per thread. A render call keeps its state on the instance until it returns. The docs said the renderer stores no per-document state; that was not true of earlier versions either.
- The title of a spoiler is written as text in front of it, `Reveal: [spoiler]…[/spoiler]`, in html_mode too. It was `[spoiler=Reveal]…[/spoiler]`, and Discourse never reads that attribute, so the title was lost on every site.
- `RenderingInterface` has `previous_sibling(element)`, `next_sibling(element)` and `sibling(element, offset:)`. For the element the renderer is rendering right now they look at the children of its parent, also when that parent has no tag of its own. For any other element they look at the children of the element on top of the parent chain, or of `RenderContext#root` when the chain is empty. `previous_list(element)` returns the last list in front of the element with nothing visible between them.
- An empty quote, an empty code block and an empty details block are written as a blank line, so the text in front of it and after it stays apart, like around any other block. They were written as nothing, and `x[quote][/quote]y` became `xy`. In html_mode they are still written as nothing, a blank line would end the HTML block.
- A line break written as `<br>` at the start or the end of a link label or of emphasis moves out of the brackets or the markers, like whitespace does: `see\n<br>[label](url)` instead of `see\n[<br>label](url)`. It shows the same.
- `AST::Url#bare?` is also true when the text is the href with whitespace at its edges, or with line breaks in front of it or after it: `[url] https://example.com [/url]`, or `[url]` followed by a line break. Such a link is written as the bare URL, with the whitespace and the line breaks outside it, so it can onebox like a link whose text is exactly the href. It was written as `[https://example.com](https://example.com)`. A custom Url tag that relies on `bare?` sees the same.
- A bare URL right after a `<br>` stays bare: markdown-it reads the `<br>` as an HTML tag of its own and links the URL after it.
- `Markbridge::Renderers::Discourse::Inline::Tokens.placeholder(text, like:)` is a new token for a placeholder that a later step replaces, like an importer that swaps `[link|17]` for a URL. The serializer writes `text` as it is and joins it with its neighbors as if `like` stood there, so `<!---->` goes in where the replacement needs it. [Placeholders](/migrating/placeholders/#tell-markbridge-what-replaces-the-placeholder) explains when to use it and how to pick `like:`.
- An upload inside the cell of a Markdown table has the `|` in front of its dimensions and in front of the `attachment` marker escaped, `![a\|64x64](upload://a.png)` and `[a.pdf\|attachment](upload://a.pdf)`, also in the raw Markdown an `AST::Upload` carries. Without the backslash the pipe ended the cell in plain markdown-it and in Discourse before August 2026; Discourse reads the dimensions and the marker with the backslash as well.
- The destination of an upload is written like the destination of a link: a parenthesis or a backslash in the file name gets a backslash, a file name with whitespace is wrapped in `<…>`. A `<` or `>` inside such a wrapped destination gets a backslash too, for links and images as well; it ended the destination before.
- An upload inside a table the renderer writes as HTML is a Markdown island in a `<div>`, `<div>\n\n![a|64x64](upload://a.png)\n\n</div>`, instead of `<img src="upload://a.png" alt="a">` or `<a href="upload://a.pdf">a.pdf</a>`. Discourse reads the dimensions and the `attachment` marker only from its Markdown forms, and its sanitizer drops the `upload://` href of a raw HTML link, so the attachment had no link there. The raw Markdown an `AST::Upload` carries is written that way too.
- The `[poll]` and `[event]` BBCode and an `AST::MarkdownText` inside such a table are the same island in a `<div>`, instead of the BBCode between bare blank lines. The `div` closes the island: after bare blank lines the rest of the cell is Markdown until a line opens an HTML block again, so a `~~~` in the text after the poll opened a code fence, and a poll first in the cell was raw text. `RenderingInterface#markdown_island(markdown, block:)` is new and writes the form a tag needs in both modes: the Markdown itself outside an HTML block, with blank lines around it when `block: true`, and the island in a `<div>` inside one. A custom tag that writes the BBCode of a plugin or a placeholder for one goes through it (the placeholder guide shows how). `HtmlBlock.enclosed_island(markdown)` builds the island. `HtmlBlock.safe?`, and with it the shared example `an html_mode safe tag`, accept the island in a `<div>` and no longer accept a bare island or any other blank line in html_mode output.
- A file attachment (an `AST::Upload` of type `attachment` without raw Markdown) inside a link or a mail link is written as its file name and size, `[report.pdf (1 KB)](https://example.com)`, without a link of its own. Markdown has no link inside a link: the inner one won, and the brackets of the outer link stayed text. The normalizer treats a link inside a link the same way. An image upload inside a link keeps its form.
- A text with a blank line in it, written in html_mode, has the newline in front of the blank line written as `&#10;`, like the serializer already wrote it for inline tokens. The blank line ended the HTML block, and the rest of the table cell was Markdown.
- A list next to the plain form of a details block or a poll (`features: { details: false }` or `{ poll: false }`) gets the other marker, like a list after a list of the same kind, so the two do not merge. `Tag` has two new hooks for that, `leading_list(element, interface)` and `trailing_list(element, interface)`: a tag whose output starts or ends with the output of a child answers with that child's list (`interface.leading_list(element, children: true)`), a tag whose output is a list of its own with the element, the default is nil. An element without a tag is looked through. `RenderingInterface#leading_list(node, children: false)` and `#trailing_list` ask the renderer, `#previous_list(element)` can return such a node now, and `#choose_list_marker(node, ordered:)` picks the marker for a list or a node that writes one, which `#list_marker(node)` returns afterwards; `ListItemTag` and `HorizontalRuleTag` read it.

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

You can edit the parsed tree before it is rendered, for example to add attachments that were not in the text of the post. Every `*_to_markdown` / `convert` method takes a block, or you can render a `Parse` by hand:

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
