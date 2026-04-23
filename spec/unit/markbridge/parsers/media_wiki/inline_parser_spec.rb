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

  describe "internal links" do
    it "parses [[Page Name]]" do
      doc = parse("[[Page Name]]")
      expect(doc.children.size).to eq(1)

      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("Page Name")
      expect(url.children.first.text).to eq("Page Name")
    end

    it "parses [[Page Name|display text]]" do
      doc = parse("[[Page Name|display text]]")
      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("Page Name")
      expect(url.children.first.text).to eq("display text")
    end

    it "preserves pipes after the first in the display text" do
      doc = parse("[[Page|a|b]]")

      url = doc.children.first
      expect(url.href).to eq("Page")
      expect(url.children.first.text).to eq("a|b")
    end

    it "strips whitespace around the target" do
      doc = parse("[[  Page  ]]")

      expect(doc.children.first.href).to eq("Page")
    end

    it "strips whitespace around the display text" do
      doc = parse("[[Page|  display  ]]")

      expect(doc.children.first.children.first.text).to eq("display")
    end

    it "treats unclosed [[ as text" do
      doc = parse("[[unclosed link")
      expect(doc.children.first.text).to eq("[[unclosed link")
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
      expect(url.href).to eq("Page")
    end

    it "dispatches on the character at `@pos + 1`, not at index 1" do
      # External link first, then an internal link later in the string.
      # The second `[` opens at @pos=6; its next char must be read at @pos+1,
      # not at a fixed input[1].
      doc = parse("[x y] [[Page]]")

      expect(doc.children.map(&:class)).to include(Markbridge::AST::Url)
      internal = doc.children.last
      expect(internal).to be_a(Markbridge::AST::Url)
      expect(internal.href).to eq("Page")
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

    it "parses <del>...</del> as strikethrough" do
      doc = parse("<del>deleted</del>")
      expect(doc.children.first).to be_a(Markbridge::AST::Strikethrough)
    end

    it "parses <u>...</u> as underline" do
      doc = parse("<u>underlined</u>")
      expect(doc.children.first).to be_a(Markbridge::AST::Underline)
      expect(doc.children.first.children.first.text).to eq("underlined")
    end

    it "parses <ins>...</ins> as underline" do
      doc = parse("<ins>inserted</ins>")
      expect(doc.children.first).to be_a(Markbridge::AST::Underline)
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

    # Kills `.downcase` drop on `tag_match[2].downcase`. The opening
    # regex has the `/i` flag so <CODE> matches it and dispatches to
    # handle_paired_raw_tag. That helper builds the closing tag as
    # "</" + tag_name + ">" — with downcase the lookup is case-sensitive
    # against "</code>" which doesn't match "</CODE>", so the whole
    # region falls through to literal text. Without downcase, tag_name
    # stays "CODE" and the closing tag DOES match, producing an
    # AST::Code node. Asserting the literal-text outcome pins the
    # downcase behaviour.
    it "treats uppercase <CODE>...</CODE> as literal text" do
      doc = parse("<CODE>X</CODE>")
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("<CODE>X</CODE>")
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

  # Loop-progress guard: every iteration of the main dispatch loop
  # must advance @pos. If a bug in a `parse_*` helper leaves @pos
  # unchanged, we raise ParserStuckError instead of hanging.
  describe "loop-progress guard" do
    it "raises ParserStuckError if a subclass override stalls the loop" do
      buggy =
        Class.new(described_class) do
          # Override append_literal so it doesn't advance @pos. Any plain
          # text would trigger the guard on the first iteration.
          define_method(:append_literal) { |_char| }
          private :append_literal
        end

      expect { buggy.new.parse("abc", parent:) }.to raise_error(
        Markbridge::ParserStuckError,
        /stuck at position 0/,
      )
    end

    it "resets guard state between successive parses on the same instance" do
      parser = described_class.new
      first_parent = Markbridge::AST::Paragraph.new
      parser.parse("hello world", parent: first_parent)

      # Without reset, @last_progress_pos from the prior parse would
      # cause the first progressed!(0) of the second parse to raise.
      second_parent = Markbridge::AST::Paragraph.new
      expect { parser.parse("second run", parent: second_parent) }.not_to raise_error
      expect(second_parent.children.first).to be_a(Markbridge::AST::Text)
    end
  end
end
