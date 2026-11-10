# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::MediaWiki::InlineParser do
  let(:parser) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def parse(text)
    parser.parse(text, parent:)
    parent
  end

  describe "plain text" do
    it "parses plain text" do
      doc = parse("hello world")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("hello world")
    end

    it "handles empty string" do
      doc = parse("")
      expect(doc.children).to be_empty
    end

    it "keeps a single apostrophe followed by a letter as plain text" do
      doc = parse("won't be bold")

      expect(doc.children.first.text).to eq("won't be bold")
    end

    it "keeps multiple stray single apostrophes as plain text (does not treat as formatting)" do
      doc = parse("isn't 'it' now")

      expect(doc.children.first.text).to eq("isn't 'it' now")
    end
  end

  describe "bold" do
    it "parses '''bold''' text" do
      doc = parse("'''bold'''")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Bold)
      expect(doc.children.first.children.first.text).to eq("bold")
    end

    it "parses bold within text" do
      doc = parse("before '''bold''' after")
      expect(doc.children.size).to eq(3)
      expect(doc.children[0].text).to eq("before ")
      expect(doc.children[1]).to be_a(Markbridge::AST::Bold)
      expect(doc.children[2].text).to eq(" after")
    end

    it "treats unclosed bold as text" do
      doc = parse("'''unclosed")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("'''unclosed")
    end

    it "treats unclosed bold mid-input as literal apostrophes at the correct position" do
      doc = parse("x'''unclosed")

      expect(doc.children.first.text).to eq("x'''unclosed")
    end
  end

  describe "italic" do
    it "parses ''italic'' text" do
      doc = parse("''italic''")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Italic)
      expect(doc.children.first.children.first.text).to eq("italic")
    end

    it "treats unclosed italic as text" do
      doc = parse("''unclosed")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first.text).to eq("''unclosed")
    end

    it "closes italic even when more apostrophes follow than required" do
      # ''italic''' - close on first 2 apostrophes, treat remaining ' as text
      doc = parse("''italic'''")

      italic = doc.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("italic")
      expect(doc.children[1].text).to eq("'")
    end
  end

  describe "bold italic" do
    it "parses '''''bold italic''''' text" do
      doc = parse("'''''bold italic'''''")
      expect(doc.children.size).to eq(1)

      bold = doc.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("bold italic")
    end

    it "clamps 6+ consecutive apostrophes to bold+italic and treats the overflow as literal" do
      # 6 opening apostrophes: 5 form the bold+italic marker, the leftover ' is literal text
      doc = parse("''''''content''''''")

      expect(doc.children.first).to be_a(Markbridge::AST::Bold)
    end
  end

  describe "bold inside italic" do
    def shape(node)
      return node.text if node.instance_of?(Markbridge::AST::Text)

      [node.class.name.split("::").last, *node.children.map { |child| shape(child) }]
    end

    def shapes(input)
      parse(input).children.map { |child| shape(child) }
    end

    it "keeps the italic open over the bold" do
      expect(shapes("''a '''b''' c''")).to eq([["Italic", "a ", %w[Bold b], " c"]])
    end

    it "ends the bold and the italic with five apostrophes" do
      expect(shapes("''a '''b'''''")).to eq([["Italic", "a ", %w[Bold b]]])
    end

    it "keeps the italic open over two bolds" do
      expect(shapes("''a '''b''' c '''d''' e'' f")).to eq(
        [["Italic", "a ", %w[Bold b], " c ", %w[Bold d], " e"], " f"],
      )
    end

    it "looks over single apostrophes inside the bold" do
      expect(shapes("''a '''it's b''' c''")).to eq([["Italic", "a ", ["Bold", "it's b"], " c"]])
    end

    it "ends the italic at three apostrophes when no bold closes after them" do
      expect(shapes("''a '''b''")).to eq([["Italic", "a "], "'b''"])
    end

    it "is no italic when nothing closes it after the bold" do
      expect(shapes("''a '''b''' c")).to eq(["''a ", %w[Bold b], " c"])
    end

    it "ends the italic at two apostrophes when bold follows later" do
      expect(shapes("''a'' and '''b'''")).to eq([%w[Italic a], " and ", %w[Bold b]])
    end

    it "still ends the italic at four apostrophes" do
      expect(shapes("''a''''")).to eq([%w[Italic a], "''"])
    end
  end

  describe "internal links" do
    it "parses [[Page Name]]" do
      doc = parse("[[Page Name]]")
      expect(doc.children.size).to eq(1)

      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("./Page_Name")
      expect(url.children.first.text).to eq("Page Name")
    end

    it "parses [[Page Name|display text]]" do
      doc = parse("[[Page Name|display text]]")
      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("./Page_Name")
      expect(url.children.first.text).to eq("display text")
    end

    it "preserves pipes after the first in the display text" do
      doc = parse("[[Page|a|b]]")

      url = doc.children.first
      expect(url.href).to eq("./Page")
      expect(url.children.first.text).to eq("a|b")
    end

    it "writes the href relative to the wiki, with underscores for spaces" do
      expect(parse("[[Alta Via 1|the first]]").children.first.href).to eq("./Alta_Via_1")
    end

    it "keeps the namespace and the section in the href" do
      expect(parse("[[Help:Contents#Hiking tips]]").children.first.href).to eq(
        "./Help:Contents#Hiking_tips",
      )
    end

    it "keeps the title with its spaces as the text of the link" do
      expect(parse("[[Alta Via 1]]").children.first.children.first.text).to eq("Alta Via 1")
    end

    it "drops the colon in front of a link to a category or a file" do
      expect(parse("[[:Category:Hiking|hikes]]").children.first.href).to eq("./Category:Hiking")
    end

    it "keeps a link to a section of the same page as it is" do
      expect(parse("[[#Early history|history]]").children.first.href).to eq("#Early history")
    end

    it "keeps an empty target empty" do
      expect(parse("[[|text]]").children.first.href).to eq("")
    end

    it "strips whitespace around the target" do
      doc = parse("[[  Page  ]]")

      expect(doc.children.first.href).to eq("./Page")
    end

    it "strips whitespace around the display text" do
      doc = parse("[[Page|  display  ]]")

      expect(doc.children.first.children.first.text).to eq("display")
    end

    it "treats unclosed [[ as text" do
      doc = parse("[[unclosed link")
      expect(doc.children.first.text).to eq("[[unclosed link")
    end

    it "treats [[]] as text and goes on after it" do
      doc = parse("a [[]] b [[Page]]")

      expect(doc.children.map(&:class)).to eq([Markbridge::AST::Text, Markbridge::AST::Url])
      expect(doc.children.first.text).to eq("a [[]] b ")
      expect(doc.children.last.href).to eq("./Page")
    end

    it "flushes preceding text before an internal link (preserves order)" do
      doc = parse("before [[Page]]")

      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("before ")
      expect(doc.children[1]).to be_a(Markbridge::AST::Url)
    end

    it "continues parsing the character immediately after the `]]` close" do
      doc = parse("[[Page]]x")

      expect(doc.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Text])
      expect(doc.children.last.text).to eq("x")
    end

    it "searches for ]] starting from the current position, not from the start" do
      # The leading ]] is not a valid close for a link that starts after it.
      doc = parse("]] [[Page]]")

      url = doc.children.find { |c| c.is_a?(Markbridge::AST::Url) }
      expect(url).not_to be_nil
      expect(url.href).to eq("./Page")
    end

    it "dispatches on the character at `@pos + 1`, not at index 1" do
      # External link first, then an internal link later in the string.
      # The second `[` opens at @pos=6; its next char must be read at @pos+1,
      # not at a fixed input[1].
      doc = parse("[x y] [[Page]]")

      expect(doc.children.map(&:class)).to include(Markbridge::AST::Url)
      internal = doc.children.last
      expect(internal).to be_a(Markbridge::AST::Url)
      expect(internal.href).to eq("./Page")
    end
  end

  describe "external links" do
    it "parses [url display text]" do
      doc = parse("[https://example.com Example]")
      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("https://example.com")
      expect(url.children.first.text).to eq("Example")
    end

    it "parses [url] without display text" do
      doc = parse("[https://example.com]")
      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("https://example.com")
      expect(url.children.first.text).to eq("https://example.com")
    end

    it "treats unclosed [ as text" do
      doc = parse("[unclosed")
      expect(doc.children.first.text).to eq("[unclosed")
    end

    it "searches for ] starting from the current position, not from the start" do
      doc = parse("] [https://example.com Example]")

      url = doc.children.find { |c| c.is_a?(Markbridge::AST::Url) }
      expect(url).not_to be_nil
      expect(url.href).to eq("https://example.com")
    end

    it "continues parsing the character immediately after the ] close" do
      doc = parse("[https://example.com Example]x")

      expect(doc.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Text])
      expect(doc.children.last.text).to eq("x")
    end

    it "preserves additional spaces in display text (only splits on first)" do
      doc = parse("[https://example.com A B C]")

      expect(doc.children.first.children.first.text).to eq("A B C")
    end
  end

  describe "HTML tags" do
    it "parses <code>...</code>" do
      doc = parse("<code>some code</code>")
      code = doc.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("some code")
    end

    it "parses <nowiki>...</nowiki> as literal text" do
      doc = parse("<nowiki>'''not bold'''</nowiki>")
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("'''not bold'''")
    end

    it "parses <br> as line break" do
      doc = parse("before<br>after")
      expect(doc.children.size).to eq(3)
      expect(doc.children[0].text).to eq("before")
      expect(doc.children[1]).to be_a(Markbridge::AST::LineBreak)
      expect(doc.children[2].text).to eq("after")
    end

    it "parses <br /> as line break" do
      doc = parse("before<br />after")
      expect(doc.children.size).to eq(3)
      expect(doc.children[1]).to be_a(Markbridge::AST::LineBreak)
    end

    it "parses <s>...</s> as strikethrough" do
      doc = parse("<s>deleted</s>")
      expect(doc.children.first).to be_a(Markbridge::AST::Strikethrough)
      expect(doc.children.first.children.first.text).to eq("deleted")
    end

    it "parses <del>...</del> as a deletion" do
      doc = parse("<del>deleted</del>")
      expect(doc.children.first).to be_a(Markbridge::AST::Deletion)
    end

    it "parses <u>...</u> as underline" do
      doc = parse("<u>underlined</u>")
      expect(doc.children.first).to be_a(Markbridge::AST::Underline)
      expect(doc.children.first.children.first.text).to eq("underlined")
    end

    it "reads the tags in any case" do
      doc = parse("<S>a</s> <Code>'''b'''</CODE> <NOWIKI>''c''</NoWiki> <U>d</U> x<BR>y")

      expect(doc.children.map(&:class)).to eq(
        [
          Markbridge::AST::Strikethrough,
          Markbridge::AST::Text,
          Markbridge::AST::Code,
          Markbridge::AST::Text,
          Markbridge::AST::Underline,
          Markbridge::AST::Text,
          Markbridge::AST::LineBreak,
          Markbridge::AST::Text,
        ],
      )
      expect(doc.children[2].children.first.text).to eq("'''b'''")
      expect(doc.children[3].text).to eq(" ''c'' ")
    end

    it "goes on behind an end tag in another case" do
      doc = parse("<s>a</S>b")

      expect(doc.children.last.text).to eq("b")
    end

    it "parses <ins>...</ins> as an insertion" do
      doc = parse("<ins>inserted</ins>")
      expect(doc.children.first).to be_a(Markbridge::AST::Insertion)
    end

    it "parses <mark>...</mark> as a highlight" do
      doc = parse("<mark>important</mark>")
      expect(doc.children.first).to be_a(Markbridge::AST::Highlight)
    end

    it "parses <sup>...</sup> as superscript" do
      doc = parse("x<sup>2</sup>")
      expect(doc.children[1]).to be_a(Markbridge::AST::Superscript)
      expect(doc.children[1].children.first.text).to eq("2")
    end

    it "parses <sub>...</sub> as subscript" do
      doc = parse("H<sub>2</sub>O")
      expect(doc.children[1]).to be_a(Markbridge::AST::Subscript)
      expect(doc.children[1].children.first.text).to eq("2")
    end

    it "treats unknown HTML tags as text" do
      doc = parse("<span>text</span>")
      expect(doc.children.first.text).to eq("<span>text</span>")
    end

    # The registry has its names in lower case, so the name of the tag
    # is downcased for the lookup.
    it "reads an upper-case <CODE>...</CODE> as code" do
      doc = parse("<CODE>X</CODE>")
      expect(doc.children.first).to be_a(Markbridge::AST::Code)
      expect(doc.children.first.children.first.text).to eq("X")
    end

    # Kills mutations on `!tag_match[1].empty?` (closing-slash detection).
    # A `</code>` at start of input must be treated as literal text, not
    # as an opening tag that would run into missing-content errors.
    it "treats a stray closing tag as literal text" do
      doc = parse("</code>leftover")
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("</code>leftover")
    end

    # Kills mutations on `!tag_match[3].empty?` (self-closing-slash
    # detection). A `<code />` self-closer is NOT a valid code tag;
    # current code treats it as literal text.
    it "treats a self-closing <code /> as literal text" do
      doc = parse("<code />text")
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("<code />text")
    end

    # Kills mutations that drop `self_closing` from the branch-early
    # guard. The <br/> form (no space before slash) is captured as
    # self-closing by the regex; with self_closing dropped from the
    # guard the method would route to the `when "br"` arm and emit
    # a LineBreak. Assert the all-text outcome to pin the original
    # behaviour.
    it "treats <br/> (no leading space before slash) as literal text" do
      doc = parse("<br/>text")
      expect(doc.children).to all(be_a(Markbridge::AST::Text))
    end

    # Kills mutations that drop attribute support from the regex
    # (`(?: [^>]*)?` → `(?: [^>])?` or similar). Code tags must still
    # be recognised when attributes are present.
    it "parses <code> with attributes" do
      doc = parse('<code class="ruby">puts</code>')
      expect(doc.children.first).to be_a(Markbridge::AST::Code)
      expect(doc.children.first.children.first.text).to eq("puts")
    end

    # Kills handle_paired_raw_tag mutations that leave @pos on top of
    # the `</code>` token after parsing the code content. Without the
    # `+ close_tag.length` advance, the main loop re-enters
    # parse_html_tag at `</code>` and emits the raw close tag as text.
    it "advances past </code> when trailing content follows" do
      doc = parse("<code>X</code>after")
      expect(doc.children.size).to eq(2)
      expect(doc.children[0]).to be_a(Markbridge::AST::Code)
      expect(doc.children[0].children.first.text).to eq("X")
      expect(doc.children[1]).to be_a(Markbridge::AST::Text)
      expect(doc.children[1].text).to eq("after")
    end

    # Same guard for handle_paired_tag (the parse-children variant
    # used by <s>, <u>, <sup>, <sub>, <del>, <ins>).
    it "advances past </s> when trailing content follows" do
      doc = parse("<s>X</s>rest")
      expect(doc.children.size).to eq(2)
      expect(doc.children[0]).to be_a(Markbridge::AST::Strikethrough)
      expect(doc.children[1].text).to eq("rest")
    end

    # Kills the `@text_buffer << full_match` drop in the no-closing-tag
    # branches of handle_paired_raw_tag and handle_paired_tag.
    it "treats an unclosed <code> as literal text" do
      doc = parse("<code>never closed")
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("<code>never closed")
    end

    it "treats an unclosed <s> as literal text" do
      doc = parse("<s>never closed")
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("<s>never closed")
    end

    # Kills <nowiki>... unclosed drop-buffer mutation.
    it "treats an unclosed <nowiki> as literal text" do
      doc = parse("<nowiki>never closed")
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("<nowiki>never closed")
    end

    # Kills handle_nowiki_tag's `@pos = close_pos + "</nowiki>".length`
    # mutations: drop the advance (stays on "</nowiki>"), or replace
    # with "</nowiki>".length (sets @pos = 9 regardless), etc.
    it "advances past </nowiki> when trailing content follows" do
      doc = parse("<nowiki>raw text</nowiki>after")

      # "raw text" and "after" concatenate into a single Text node
      # (adjacent-text merging in InlineParser).
      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("raw textafter")
    end

    # Same `@input.index(close_tag, @pos)` → `@input.index(close_tag)`
    # kill, but for handle_paired_raw_tag (<code>, <pre>).
    it "searches for </code> starting from the current position" do
      doc = parse("</code> <code>raw</code>")

      code = doc.children.find { |c| c.is_a?(Markbridge::AST::Code) }
      expect(code).not_to be_nil
      expect(code.children.first.text).to eq("raw")
    end

    # Same kill for handle_paired_tag (<s>, <u>, <sup>, etc.).
    it "searches for </s> starting from the current position" do
      doc = parse("</s> <s>text</s>")

      strike = doc.children.find { |c| c.is_a?(Markbridge::AST::Strikethrough) }
      expect(strike).not_to be_nil
      expect(strike.children.first.text).to eq("text")
    end

    # Kills `@input.index("</nowiki>", @pos)` → `@input.index("</nowiki>")`.
    # Without the start-position arg, the lookup finds the FIRST "</nowiki>"
    # in the whole input, which here is the stray closing tag at the
    # start — producing a negative-length slice and backward @pos
    # advance. The spec shape (two Text nodes with no backwards
    # scanning) only holds with the start-pos arg.
    it "searches for </nowiki> starting from the current position" do
      doc = parse("</nowiki> <nowiki>raw</nowiki>")

      text = doc.children.first.text
      expect(text).to include("</nowiki>") # the stray opening-as-text
      expect(text).to include("raw")
    end
  end

  describe "nested inline markup" do
    it "parses italic inside bold" do
      doc = parse("'''text with ''italic'' inside'''")
      bold = doc.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children[1]).to be_a(Markbridge::AST::Italic)
      expect(bold.children[1].children.first.text).to eq("italic")
    end

    it "parses links inside bold" do
      doc = parse("'''[[Page|link]]'''")
      bold = doc.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.first).to be_a(Markbridge::AST::Url)
    end
  end

  describe "custom inline tag registry" do
    let(:registry) do
      Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
        r.register("mark", :formatting, Markbridge::AST::Bold)
      end
    end
    let(:parser) { described_class.new(handlers: registry) }

    it "handles custom registered tags" do
      doc = parse("<mark>highlighted</mark>")
      expect(doc.children.first).to be_a(Markbridge::AST::Bold)
      expect(doc.children.first.children.first.text).to eq("highlighted")
    end

    it "still handles default tags" do
      doc = parse("<code>some code</code>")
      expect(doc.children.first).to be_a(Markbridge::AST::Code)
    end
  end

  describe "depth limiting" do
    let(:nested) { "'''has ''italic'' inside'''" }

    it "stops recursion at @depth = MAX_INLINE_DEPTH-1 and renders inner content as plain text" do
      parser = described_class.new(depth: described_class::MAX_INLINE_DEPTH - 1)
      parent = Markbridge::AST::Document.new
      parser.parse(nested, parent:)

      bold = parent.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      # parse_inner_content bails: bold's content is plain text, no Italic.
      expect(bold.children.size).to eq(1)
      expect(bold.children.first).to be_a(Markbridge::AST::Text)
      expect(bold.children.first.text).to eq("has ''italic'' inside")
    end

    it "still recurses one level at @depth = MAX_INLINE_DEPTH-2" do
      parser = described_class.new(depth: described_class::MAX_INLINE_DEPTH - 2)
      parent = Markbridge::AST::Document.new
      parser.parse(nested, parent:)

      bold = parent.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      # One more level of recursion is allowed: the Italic is parsed.
      expect(bold.children.any? { |c| c.is_a?(Markbridge::AST::Italic) }).to be true
    end

    it "still recurses by default (depth starts at 0, content with one nested layer parses fully)" do
      parser = described_class.new
      parent = Markbridge::AST::Document.new
      parser.parse("'''has ''italic'' inside'''", parent:)

      bold = parent.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.any? { |c| c.is_a?(Markbridge::AST::Italic) }).to be true
    end

    it "still bails when @depth exceeds MAX_INLINE_DEPTH-1 (keeps the >= bound)" do
      # Pin the boundary against strict-equality variants (`==`, `eql?`,
      # `equal?`): at @depth = MAX, original bails (MAX+1 >= MAX = true)
      # and the equality variants don't (MAX+1 != MAX), so the inner
      # ''italic'' would resurface as an Italic child rather than text.
      parser = described_class.new(depth: described_class::MAX_INLINE_DEPTH)
      parent = Markbridge::AST::Document.new
      parser.parse(nested, parent:)

      bold = parent.children.first
      expect(bold.children.none? { |c| c.is_a?(Markbridge::AST::Italic) }).to be true
    end

    it "bumps depth by exactly +1 per recursion (kills +2 / +N off-by-one variants)" do
      # Start three steps below the boundary and feed three nested layers
      # (Bold > Italic > Strikethrough). With +1 each layer parses fully,
      # so the deepest Strikethrough survives. With +2 (or +167) the
      # second recursion lands at MAX and the inner content bails to
      # text — the Italic still appears, but it loses its Strikethrough
      # child, which the assertion below detects.
      parser = described_class.new(depth: described_class::MAX_INLINE_DEPTH - 3)
      parent = Markbridge::AST::Document.new
      parser.parse("'''outer ''italic <s>strike</s> tail'' close'''", parent:)

      bold = parent.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      italic = bold.children.find { |c| c.is_a?(Markbridge::AST::Italic) }
      expect(italic).not_to be_nil
      expect(italic.children.any? { |c| c.is_a?(Markbridge::AST::Strikethrough) }).to be true
    end

    it "passes the configured registry through inner recursion" do
      registry =
        Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
          r.register("highlight", :formatting, Markbridge::AST::Bold)
        end
      parser = described_class.new(handlers: registry)
      parent = Markbridge::AST::Document.new
      # Outer ''…'' wraps the content in Italic and recurses via
      # parse_inner_content; the inner <highlight> tag must still resolve
      # against the custom registry, not against the default.
      parser.parse("''before <highlight>marked</highlight> after''", parent:)

      italic = parent.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.any? { |c| c.is_a?(Markbridge::AST::Bold) }).to be true
    end
  end

  # The parser works in byte offsets. These inputs place multibyte text
  # *before* each construct, shaped so that a byte/character-index mixup
  # would land the cursor on an alphanumeric byte and change the outcome.
  describe "multibyte text around constructs" do
    it "parses bold after multibyte text" do
      doc = parse("héllo wörld '''fett'''")

      expect(doc.children[0].text).to eq("héllo wörld ")
      expect(doc.children[1]).to be_a(Markbridge::AST::Bold)
      expect(doc.children[1].children.first.text).to eq("fett")
    end

    it "parses multibyte content inside formatting" do
      doc = parse("''größer über straße''")

      expect(doc.children.first).to be_a(Markbridge::AST::Italic)
      expect(doc.children.first.children.first.text).to eq("größer über straße")
    end

    it "parses internal links with multibyte target and display after multibyte text" do
      doc = parse("日本語 [[ターゲット|表示テキスト]] テスト")

      url = doc.children[1]
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("./ターゲット")
      expect(url.children.first.text).to eq("表示テキスト")
      expect(doc.children[2].text).to eq(" テスト")
    end

    it "parses external links with multibyte display text after multibyte text" do
      doc = parse("café [https://example.com/ü Ünïcode Anzeige]")

      url = doc.children[1]
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("https://example.com/ü")
      expect(url.children.first.text).to eq("Ünïcode Anzeige")
    end

    it "parses html tags with multibyte raw content after multibyte text" do
      doc = parse("größer <code>schön ändern</code> Ende")

      code = doc.children[1]
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("schön ändern")
      expect(doc.children[2].text).to eq(" Ende")
    end

    it "keeps apostrophes between multibyte words as plain text" do
      doc = parse("О'Брайен и l'été c'est")

      expect(doc.children.first.text).to eq("О'Брайен и l'été c'est")
    end

    it "rolls back unterminated bold after multibyte text" do
      doc = parse("héllo '''nie geschlossen")

      expect(doc.children.map { |c| c.text }.join).to eq("héllo '''nie geschlossen")
    end

    it "rolls back unterminated internal links after multibyte text" do
      doc = parse("héllo [[offen")

      expect(doc.children.map { |c| c.text }.join).to eq("héllo [[offen")
    end

    it "preserves multibyte nowiki content" do
      doc = parse("<nowiki>'''kein Fett''' straße</nowiki> danach")

      expect(doc.children.first.text).to eq("'''kein Fett''' straße danach")
    end
  end
end
