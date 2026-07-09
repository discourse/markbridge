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

      it "advances by exactly one char past the `:` with empty UID suffix" do
        # Kills `@current_pos += 1` → `+= 2` on the post-colon step.
        # With `+= 2`, the scanner would jump past the closing `]`
        # and fail to consume it, rolling the tag back to text.
        tokens = scan("[quote:]")

        expect(tokens[0]).to match_tag_start("quote:")
      end

      it "advances by exactly one char per UID hex char consumed" do
        # Kills `@current_pos += 1` → `+= 2` inside the UID hex loop.
        # Single-hex-char UID: with `+= 2`, the scanner would skip the
        # closing `]` and roll back.
        tokens = scan("[quote:a]")

        expect(tokens[0]).to match_tag_start("quote:a")
      end

      it "does not raise when input ends mid-UID suffix" do
        # Kills `current_char&.match?(UID_HEX_CHAR)` → `.match?(UID_HEX_CHAR)`
        # (drop safe-nav). At end-of-input current_char is nil;
        # `nil.match?` would raise NoMethodError, while `nil&.match?`
        # exits the loop cleanly and the unterminated tag rolls back.
        expect { scan("[quote:a") }.not_to raise_error
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

    # The scanner classifies bytes with integer range checks (e.g.
    # a-z == 97..122). Each example probes one range endpoint or a byte
    # directly adjacent to it, so off-by-one mutations on any bound flip
    # the outcome.
    context "with ASCII byte-class boundaries" do
      it "accepts tag names at the letter-range boundaries" do
        expect(scan("[a]")[0]).to match_tag_start("a")
        expect(scan("[z]")[0]).to match_tag_start("z")
        expect(scan("[A]")[0]).to match_tag_start("a")
        expect(scan("[Z]")[0]).to match_tag_start("z")
      end

      it "rejects initial bytes adjacent to the letter ranges" do
        # ` (0x60) and { (0x7B) flank a-z; @ (0x40) and \ (0x5C) flank A-Z
        expect(scan("[`x]")[0]).to match_text_token("[")
        expect(scan("[{x]")[0]).to match_text_token("[")
        expect(scan("[@x]")[0]).to match_text_token("[")
        expect(scan("[\\x]")[0]).to match_text_token("[")
      end

      it "accepts tag-name bytes at the letter and digit boundaries" do
        expect(scan("[qa]")[0]).to match_tag_start("qa")
        expect(scan("[qz]")[0]).to match_tag_start("qz")
        expect(scan("[qA]")[0]).to match_tag_start("qa")
        expect(scan("[qZ]")[0]).to match_tag_start("qz")
        expect(scan("[q0]")[0]).to match_tag_start("q0")
        expect(scan("[q9]")[0]).to match_tag_start("q9")
      end

      it "stops the tag name at bytes adjacent to the letter and digit ranges" do
        expect(scan("[q`]")[0]).to match_text_token("[")
        expect(scan("[q{]")[0]).to match_text_token("[")
        expect(scan("[q@]")[0]).to match_text_token("[")
        expect(scan("[q/]")[0]).to match_text_token("[")
      end

      it "accepts uid bytes at the hex-range boundaries" do
        expect(scan("[q:0]")[0]).to match_tag_start("q:0")
        expect(scan("[q:9]")[0]).to match_tag_start("q:9")
        expect(scan("[q:a]")[0]).to match_tag_start("q:a")
        expect(scan("[q:f]")[0]).to match_tag_start("q:f")
        expect(scan("[q:A]")[0]).to match_tag_start("q:a")
        expect(scan("[q:F]")[0]).to match_tag_start("q:f")
      end

      it "stops the uid at bytes adjacent to the hex ranges" do
        # g/G follow f/F, ` precedes a, @ precedes A; the uid ends there and
        # the leftover byte is consumed as an (empty-valued) attribute name,
        # so the tag name must stay bare.
        expect(scan("[q:g]")[0]).to match_tag_start("q:")
        expect(scan("[q:G]")[0]).to match_tag_start("q:")
        expect(scan("[q:`]")[0]).to match_text_token("[")
        expect(scan("[q:@]")[0]).to match_text_token("[")
        # / (0x2F) directly precedes 0; it is no uid byte and no attribute
        # byte either, so the whole tag rolls back
        expect(scan("[q:/]")[0]).to match_text_token("[")
      end

      it "accepts attribute-name bytes at the \\w boundaries" do
        # Ax/Zx probe bytes A and Z (keys are downcased on the way in)
        tokens = scan("[quote a=1 z=2 Ax=3 Zx=4 k0=5 k9=6 a_b=7]")

        expect(tokens[0]).to match_tag_start(
          "quote",
          a: "1",
          z: "2",
          ax: "3",
          zx: "4",
          k0: "5",
          k9: "6",
          a_b: "7",
        )
      end

      it "stops attribute names at bytes adjacent to the \\w ranges" do
        # - (0x2D) precedes 0 in ASCII; ` (0x60) precedes a
        expect(scan("[quote k-x=1]")[0]).to match_text_token("[")
        expect(scan("[quote `x=1]")[0]).to match_text_token("[")
      end

      it "treats the whitespace-class boundary bytes as attribute separators" do
        # \t (0x09) and \r (0x0D) are the endpoints of the \s control range
        expect(scan("[quote\tk=1]")[0]).to match_tag_start("quote", k: "1")
        expect(scan("[quote\rk=1]")[0]).to match_tag_start("quote", k: "1")
        expect(scan("[quote\nk=1]")[0]).to match_tag_start("quote", k: "1")
      end

      it "does not treat control bytes below \\t as whitespace" do
        # NUL (0x08 would work too) is directly below \t; if it counted as
        # whitespace the attributes would parse and this would be a tag
        expect(scan("[quote\u0000k=1]")[0]).to match_text_token("[")
      end
    end

    # The scanner works in byte offsets. These inputs place multibyte text
    # *before* each construct, shaped so that a byte/character-index mixup
    # would land the cursor on an alphanumeric byte and change the outcome.
    context "with multibyte text preceding constructs" do
      it "scans tags after multibyte text" do
        tokens = scan("héllo wörld [b]bold[/b]")

        expect(tokens.size).to eq(4)
        expect(tokens[0]).to match_text_token("héllo wörld ")
        expect(tokens[1]).to match_tag_start("b")
        expect(tokens[2]).to match_text_token("bold")
        expect(tokens[3]).to match_tag_end("b")
      end

      it "scans quoted attribute values containing multibyte text" do
        tokens = scan("café [quote=\"Ünïcode Näme\"]x[/quote]")

        expect(tokens[1]).to match_tag_start("quote", option: "Ünïcode Näme")
      end

      it "scans unquoted attribute values containing multibyte text" do
        tokens = scan("日本語 [color=rötlich]x[/color]")

        expect(tokens[1]).to match_tag_start("color", option: "rötlich")
      end

      it "scans key=value attributes after a multibyte option value" do
        tokens = scan("[quote=\"Ünïcode\" post_id=42]x[/quote]")

        expect(tokens[0]).to match_tag_start("quote", option: "Ünïcode", post_id: "42")
      end

      it "rolls back invalid tags after multibyte text" do
        tokens = scan("héllo [not a tag")

        expect(tokens.size).to eq(3)
        expect(tokens[0]).to match_text_token("héllo ")
        expect(tokens[1]).to match_text_token("[")
        expect(tokens[2]).to match_text_token("not a tag")
      end

      it "preserves multibyte text between adjacent tags" do
        tokens = scan("[b]schön[/b][i]größer[/i]")

        expect(tokens[1]).to match_text_token("schön")
        expect(tokens[4]).to match_text_token("größer")
      end
    end
  end
end
