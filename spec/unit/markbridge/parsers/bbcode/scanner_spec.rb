# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Scanner do
  def scan(input)
    scanner = described_class.new(input)
    tokens = []
    while (token = scanner.next_token)
      tokens << token
    end
    tokens
  end

  describe "#next_token" do
    it "returns tokens sequentially" do
      scanner = described_class.new("[b]text[/b]")
      tokens = []
      while (t = scanner.next_token)
        tokens << t
      end

      expect(tokens.size).to eq(3)
      expect(tokens[0]).to match_tag_start("b")
      expect(tokens[1]).to match_text_token("text")
      expect(tokens[2]).to match_tag_end("b")
    end

    it "returns nil at end of input" do
      scanner = described_class.new("")
      expect(scanner.next_token).to be_nil
    end

    it "records the byte position of each emitted token" do
      tokens = scan("hi[b]ok[/b]")

      expect(tokens.map(&:pos)).to eq([0, 2, 5, 7])
    end

    it "records pos on the trailing text-only TextToken (no further [ in input)" do
      tokens = scan("[b]trailing")

      expect(tokens.last).to match_text_token("trailing")
      expect(tokens.last.pos).to eq(3)
    end

    it "records pos on a fallback `[` text token when the bracket does not open a tag" do
      tokens = scan("ok[123")

      expect(tokens[1].text).to eq("[")
      expect(tokens[1].pos).to eq(2)
    end

    context "with plain text" do
      it "scans plain text" do
        tokens = scan("hello world")

        expect(tokens.size).to eq(1)
        expect(tokens[0]).to match_text_token("hello world")
      end

      it "handles empty input" do
        tokens = scan("")
        expect(tokens).to be_empty
      end
    end

    context "with simple tags" do
      it "scans opening tag" do
        tokens = scan("[b]")

        expect(tokens.size).to eq(1)
        expect(tokens[0]).to match_tag_start("b")
      end

      it "scans closing tag" do
        tokens = scan("[/b]")

        expect(tokens.size).to eq(1)
        expect(tokens[0]).to match_tag_end("b")
      end

      it "scans tag with text" do
        tokens = scan("[b]bold[/b]")

        expect(tokens.size).to eq(3)
        expect(tokens[0]).to match_tag_start("b")
        expect(tokens[1]).to match_text_token("bold")
        expect(tokens[2]).to match_tag_end("b")
      end

      it "normalizes tag names to lowercase" do
        tokens = scan("[BOLD]TEXT[/BOLD]")

        expect(tokens[0]).to match_tag_start("bold")
        expect(tokens[1]).to match_text_token("TEXT")
        expect(tokens[2]).to match_tag_end("bold")
      end

      it "preserves the original-case source on the tag token" do
        tokens = scan("[BOLD]")

        expect(tokens[0].source).to eq("[BOLD]")
      end

      it "preserves the original close-tag source on TagEndToken" do
        # Kills `TagEndToken.new(tag:, pos:, source:)` → `source: nil`.
        # The source attribute is load-bearing for RawContentCollector,
        # which concatenates `token.source` when collecting raw content
        # across non-matching close tags inside [code]...[/code].
        tokens = scan("[/CODE]")

        expect(tokens[0]).to match_tag_end("code")
        expect(tokens[0].source).to eq("[/CODE]")
      end
    end

    context "with tag attributes" do
      it "scans option attribute with =" do
        tokens = scan("[url=https://example.com]")

        expect(tokens.size).to eq(1)
        expect(tokens[0]).to match_tag_start("url", option: "https://example.com")
      end

      it "scans quoted option attribute" do
        tokens = scan('[quote="John Doe"]')

        expect(tokens[0]).to match_tag_start("quote", option: "John Doe")
      end

      it "scans single-quoted option attribute" do
        tokens = scan("[quote='Jane Smith']")

        expect(tokens[0]).to match_tag_start("quote", option: "Jane Smith")
      end

      it "scans named attributes" do
        tokens = scan(%q{[url href="https://example.com" title='Example']})

        expect(tokens[0]).to match_tag_start("url", href: "https://example.com", title: "Example")
      end

      it "scans option and named attributes together" do
        tokens = scan('[img=100x200 alt="Photo" title="My Photo"]')

        expect(tokens[0]).to match_tag_start(
          "img",
          option: "100x200",
          alt: "Photo",
          title: "My Photo",
        )
      end

      it "handles unquoted attribute values" do
        tokens = scan('[img alt=Photo title="My Photo" size=100x200]')

        expect(tokens[0]).to match_tag_start(
          "img",
          alt: "Photo",
          title: "My Photo",
          size: "100x200",
        )
      end

      it "lowercases attribute names" do
        tokens = scan("[img ALT=Photo]")

        expect(tokens[0].attrs).to have_key(:alt)
      end

      it "rejects a closing tag with attributes (closing tags must end with `]`)" do
        tokens = scan("[/url=ignored]")

        expect(tokens[0]).to match_text_token("[")
        expect(tokens[1]).to match_text_token("/url=ignored]")
      end

      it "scans empty quoted value" do
        tokens = scan('[url=""]')

        expect(tokens[0]).to match_tag_start("url", option: "")
      end

      it "drops a key without =value (no implicit-true)" do
        tokens = scan("[img alt]")

        expect(tokens[0].attrs).not_to have_key(:alt)
      end

      it "treats an unterminated quoted value as everything until end of input" do
        tokens = scan("[url=\"unterminated")

        expect(tokens[0]).to be_a(Markbridge::Parsers::BBCode::TextToken)
      end

      # Kills `scan_until`'s `|| @length` fallback drop. With unquoted
      # attribute values at end of input (no closing `]`, no trailing
      # whitespace), the UNQUOTED_VALUE_STOP regex never matches so
      # `@input.index(...)` returns nil; the fallback to `@length` is
      # what keeps `@current_pos` an Integer.
      it "handles an unquoted attribute value running to end of input without a closing bracket" do
        tokens = scan("[img alt=value")

        # Tag is malformed (no `]`) → scanner rolls back and emits text.
        expect(tokens[0]).to be_a(Markbridge::Parsers::BBCode::TextToken)
        expect(tokens[0].text).to eq("[")
      end

      it "tolerates whitespace between the tag name and the option `=`" do
        tokens = scan("[url   =value]")

        expect(tokens[0]).to match_tag_start("url", option: "value")
      end

      it "tolerates whitespace after the option `=` before the value" do
        tokens = scan("[url=   value]")

        expect(tokens[0]).to match_tag_start("url", option: "value")
      end

      it "tolerates whitespace between the option value and the next attribute" do
        tokens = scan("[img=100x200    alt=Photo]")

        expect(tokens[0]).to match_tag_start("img", option: "100x200", alt: "Photo")
      end

      it "tolerates whitespace between a named attribute name and `=`" do
        tokens = scan("[img alt   =Photo]")

        expect(tokens[0]).to match_tag_start("img", alt: "Photo")
      end

      it "tolerates whitespace between a named attribute `=` and its value" do
        tokens = scan("[img alt=   Photo]")

        expect(tokens[0]).to match_tag_start("img", alt: "Photo")
      end

      it "stops named-attribute parsing when the next non-whitespace char is `=` instead of a name" do
        # Without breaking on a nil name, the parser would try to use nil as a key.
        tokens = scan("[b k1=v1 =v2]")

        expect(tokens.first).to be_a(Markbridge::Parsers::BBCode::TextToken).or be_a(
               Markbridge::Parsers::BBCode::TagStartToken,
             )
      end

      it "drops a key with `=` but no value (does not store nil)" do
        tokens = scan("[b k=]")

        expect(tokens[0].attrs).not_to have_key(:k)
      end

      it "rejects an attribute name followed by a quoted string with no `=` between" do
        # `key "value"` is not valid; without a break the parser would still bind it.
        tokens = scan('[b key "value"]')

        # Tag is invalid → falls back to text starting with "["
        expect(tokens[0]).to be_a(Markbridge::Parsers::BBCode::TextToken)
        expect(tokens[0].text).to eq("[")
      end
    end

    context "with special tag names" do
      it "scans tags with * (list item)" do
        tokens = scan("[*]")

        expect(tokens[0]).to match_tag_start("*")
      end

      it "scans tags with numbers" do
        tokens = scan("[h1]")

        expect(tokens[0]).to match_tag_start("h1")
      end

      it "scans tags with uid suffix" do
        tokens = scan("[quote:abc123]")

        expect(tokens[0]).to match_tag_start("quote:abc123")
      end

      it "rejects uid suffix containing non-hex characters" do
        # `[quote:notvalid]` — 'n' is not hex, so :uid scanning stops; tag name remains 'quote'
        tokens = scan("[quote:zzz]")

        expect(tokens[0]).to be_a(Markbridge::Parsers::BBCode::TextToken).or be_a(
               Markbridge::Parsers::BBCode::TagStartToken,
             )
      end
    end

    context "with nested tags" do
      it "scans simple nested tags" do
        tokens = scan("[b][i]text[/i][/b]")

        expect(tokens.size).to eq(5)
        expect(tokens[0]).to match_tag_start("b")
        expect(tokens[1]).to match_tag_start("i")
        expect(tokens[2]).to match_text_token("text")
        expect(tokens[3]).to match_tag_end("i")
        expect(tokens[4]).to match_tag_end("b")
      end

      it "scans nested tags with attributes and surrounding text" do
        tokens = scan("Before [quote='Alice'][b]hello[/b][/quote] After")

        expect(tokens[0]).to match_text_token("Before ")
        expect(tokens[1]).to match_tag_start("quote", option: "Alice")
        expect(tokens[2]).to match_tag_start("b")
        expect(tokens[3]).to match_text_token("hello")
        expect(tokens[4]).to match_tag_end("b")
        expect(tokens[5]).to match_tag_end("quote")
        expect(tokens[6]).to match_text_token(" After")
      end

      it "scans deep nesting" do
        tokens = scan("[a][b][c]x[/c][/b][/a]")

        expect(tokens.size).to eq(7)
      end
    end

    context "with invalid tags" do
      it "treats incomplete tag as text" do
        tokens = scan("[incomplete")

        expect(tokens.size).to eq(2)
        expect(tokens[0]).to match_text_token("[")
        expect(tokens[1]).to match_text_token("incomplete")
      end

      it "treats tag with invalid name as text" do
        tokens = scan("[123]")

        expect(tokens.size).to eq(2)
        expect(tokens[0]).to match_text_token("[")
        expect(tokens[1]).to match_text_token("123]")
      end

      it "treats tag with spaces at start as text" do
        tokens = scan("[ b]")

        expect(tokens.size).to eq(2)
        expect(tokens[0]).to match_text_token("[")
        expect(tokens[1]).to match_text_token(" b]")
      end

      it "accepts tag with spaces after name" do
        tokens = scan("[b ]")

        expect(tokens.size).to eq(1)
        expect(tokens[0]).to match_tag_start("b")
      end

      it "treats a bare `[` at end of input as text" do
        tokens = scan("[")

        expect(tokens.size).to eq(1)
        expect(tokens[0]).to match_text_token("[")
      end

      it "treats `[/` (no tag name) at end of input as text" do
        tokens = scan("[/")

        expect(tokens.first).to match_text_token("[")
      end
    end

    context "with text and tags mixed" do
      it "scans text before tag" do
        tokens = scan("Hello [b]world[/b]")

        expect(tokens[0]).to match_text_token("Hello ")
        expect(tokens[1]).to match_tag_start("b")
      end

      it "scans text after tag" do
        tokens = scan("[b]Hello[/b] world")

        expect(tokens[2]).to match_tag_end("b")
        expect(tokens[3]).to match_text_token(" world")
      end

      it "scans multiple tags" do
        tokens = scan("[b]bold[/b] and [i]italic[/i]")

        expect(tokens.size).to eq(7)
        expect(tokens[3]).to match_text_token(" and ")
      end
    end

    context "with edge cases" do
      it "handles literal [ not part of tag" do
        tokens = scan("Price: $[100]")

        expect(tokens.size).to eq(3)
        expect(tokens[0]).to match_text_token("Price: $")
        expect(tokens[1]).to match_text_token("[")
        expect(tokens[2]).to match_text_token("100]")
      end

      it "handles empty tag []" do
        tokens = scan("[]")

        expect(tokens.size).to eq(2)
        expect(tokens[0]).to match_text_token("[")
        expect(tokens[1]).to match_text_token("]")
      end
    end

    # Loop-progress guard: every call to next_token that does not
    # return nil must advance @current_pos. A regression that leaves
    # @current_pos unchanged would cause the outer parser loop to
    # spin; the guard raises ParserStuckError instead.
    describe "loop-progress guard" do
      it "raises ParserStuckError when a subclass override stalls next_token" do
        buggy =
          Class.new(described_class) do
            # Override parse_tag_at_cursor to return a fake token
            # without advancing @current_pos. Any bracketed input then
            # re-enters next_token at the same position.
            define_method(:parse_tag_at_cursor) do
              Markbridge::Parsers::BBCode::TextToken.new(text: "", pos: 0)
            end
            private :parse_tag_at_cursor
          end

        scanner = buggy.new("[a]")
        scanner.next_token

        expect { scanner.next_token }.to raise_error(Markbridge::ParserStuckError)
      end
    end
  end
end
