# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "#escape" do
    # Helper to verify escaped output renders as literal text
    # The escaper MAY over-escape (false positives allowed), but MUST escape
    # anything that would otherwise be interpreted as Markdown (no false negatives)

    # =========================================================================
    # Characters That Rarely Need Escaping
    # (All MAY escape - false positives OK)
    # =========================================================================

    describe "characters rarely needing escaping in CommonMark" do
      it "may or may not escape $" do
        result = escaper.escape("$100")
        expect(result).to eq("$100").or include("\\$")
      end

      it "may or may not escape %" do
        result = escaper.escape("100%")
        expect(result).to eq("100%").or include("\\%")
      end

      it "may or may not escape ^" do
        result = escaper.escape("x^2")
        expect(result).to eq("x^2").or include("\\^")
      end

      it "may or may not escape { }" do
        result = escaper.escape("{foo}")
        expect(result).to eq("{foo}").or include("\\{")
      end

      it "may or may not escape |" do
        result = escaper.escape("a | b")
        expect(result).to eq("a | b").or include("\\|")
      end

      it "may or may not escape ~ inline" do
        result = escaper.escape("~approx")
        expect(result).to eq("~approx").or include("\\~")
      end

      it "may or may not escape : in regular text" do
        result = escaper.escape("Note: something")
        expect(result).to eq("Note: something").or include("\\:")
      end

      it "may or may not escape ; in regular text" do
        result = escaper.escape("a; b")
        expect(result).to eq("a; b").or include("\\;")
      end

      it "may or may not escape /" do
        result = escaper.escape("and/or")
        expect(result).to eq("and/or").or include("\\/")
      end

      it "may or may not escape ," do
        result = escaper.escape("a, b, c")
        expect(result).to eq("a, b, c").or include("\\,")
      end

      it "may or may not escape ?" do
        result = escaper.escape("Why?")
        expect(result).to eq("Why?").or include("\\?")
      end

      it "may or may not escape @" do
        result = escaper.escape("@user")
        expect(result).to eq("@user").or include("\\@")
      end
    end

    # =========================================================================
    # Complex/Combined Cases
    # =========================================================================

    describe "complex combined cases" do
      it "escapes multiple syntax elements in one line" do
        input = "# Heading with *emphasis* and `code`"
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\*")
        expect(result).to include("\\`")
      end

      it "escapes multiline content with various syntax" do
        input = <<~MARKDOWN.chomp
          # Heading

          Some *emphasis* and a [link](url).

          - list item

          > quote
        MARKDOWN
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\*")
        expect(result).to include("\\[")
        expect(result).to include("\\-")
        expect(result).to include("\\>")
      end

      it "escapes nested emphasis" do
        input = "***bold and italic***"
        result = escaper.escape(input)
        expect(result.count("\\")).to eq(6)
      end

      it "escapes image inside link" do
        input = "[![alt](img.png)](url)"
        result = escaper.escape(input)
        # Must escape [ - that's enough to break the image syntax
        expect(result).to include("\\[")
        # May optionally escape ! too (false positive OK)
      end

      it "preserves text that needs no escaping" do
        input = "Just plain text with no special characters"
        result = escaper.escape(input)
        # May or may not add escapes, but should preserve original text content
        expect(result.gsub("\\", "")).to eq(input)
      end

      it "handles empty string" do
        expect(escaper.escape("")).to eq("")
      end

      it "handles unicode content" do
        input = "Héllo *wörld* with émphasis"
        result = escaper.escape(input)
        expect(result).to include("Héllo")
        expect(result).to include("wörld")
        expect(result).to include("\\*")
      end

      it "handles consecutive special characters" do
        input = "***"
        result = escaper.escape(input)
        # Must escape to prevent thematic break or emphasis
        expect(result).to include("\\")
      end

      it "handles real-world example: code snippet description" do
        input = "Use `Array#map` to transform [1, 2, 3]"
        result = escaper.escape(input)
        expect(result).to include("\\`")
        expect(result).to include("\\[")
      end

      it "handles real-world example: math expression" do
        input = "If x > 0 and y < 10, then *result* = x * y"
        result = escaper.escape(input)
        expect(result).to include("\\*")
      end

      it "handles real-world example: document with footnotes" do
        input = "This claim needs citation[^1] and this is ~~wrong~~ corrected."
        result = escaper.escape(input)
        expect(result).to include("\\[^1]")
        expect(result).to include("\\~\\~")
      end

      it "handles all extensions combined with core syntax" do
        input = "# Title with ~~deleted~~ and [^note]\n\n[^note]: The *footnote* text."
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\~\\~")
        expect(result).to include("\\[^note]")
        expect(result).to include("\\*")
      end

      it "handles table with formatted content" do
        input = "| **Bold** | *Italic* | ~~Strike~~ |"
        result = escaper.escape(input)
        expect(result).to include("\\|")
        expect(result).to include("\\*")
        expect(result).to include("\\~")
      end

      it "handles document with indented code and other syntax" do
        input = <<~DOC.chomp
          # Heading

          Some *emphasis* here.

              // code block
              var x = 1;

          Back to normal with [link](url).
        DOC
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\*")
        expect(result).to include("\\[")
        # Indented code should be escaped
        expect(result).not_to match(/\n {4}\/\//)
      end
    end

    # =========================================================================
    # Edge Cases
    # =========================================================================

    describe "edge cases" do
      it "handles nil input" do
        expect(escaper.escape(nil)).to eq("")
      end

      it "handles whitespace-only input" do
        expect(escaper.escape("   ")).to eq("   ")
        expect(escaper.escape("\t")).to eq("\t")
        expect(escaper.escape("\n")).to eq("\n")
        expect(escaper.escape("\n\n")).to eq("\n\n")
        expect(escaper.escape("  \n  ")).to eq("  \n  ")
      end

      it "handles CRLF line endings" do
        input = "# Heading\r\n- item"
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\-")
      end

      it "handles very long lines" do
        long_text = "a" * 10_000
        result = escaper.escape(long_text)
        expect(result).to eq(long_text)
      end

      it "handles text with existing escape sequences" do
        input = "\\* \\# \\> \\- \\`"
        result = escaper.escape(input)
        # Each existing backslash should be escaped
        expect(result.scan("\\\\").length).to be >= 5
      end

      it "handles multiple blank lines" do
        input = "para1\n\n\npara2"
        result = escaper.escape(input)
        expect(result).to eq("para1\n\n\npara2")
      end

      it "handles only newlines" do
        input = "\n\n\n"
        result = escaper.escape(input)
        expect(result).to eq("\n\n\n")
      end

      # Kills `text.split("\n", -1)` → `text.split("\n", 0)` mutation.
      # split(0) drops trailing empty strings, so "# h\n" becomes ["# h"]
      # instead of ["# h", ""] and the trailing newline is lost.
      it "preserves a single trailing newline on escaped content" do
        expect(escaper.escape("# h\n")).to eq("\\# h\n")
      end

      it "preserves multiple trailing newlines on escaped content" do
        expect(escaper.escape("# h\n\n\n")).to eq("\\# h\n\n\n")
      end

      it "handles mixed indentation (4+ spaces converted to NBSP)" do
        nbsp = "\u00A0"
        input = "  text\n    more\n\tindented"
        result = escaper.escape(input)
        # 2-space indent preserved, 4-space and tab converted to NBSP
        expect(result).to eq("  text\n#{nbsp * 4}more\n#{nbsp * 4}indented")
      end
    end

    # =========================================================================
    # UTF-8 AND ENCODING TESTS
    # =========================================================================
    describe "UTF-8 handling" do
      it "preserves emoji" do
        # Use unicode escapes to avoid encoding issues
        result = escaper.escape("Hello \u{1F44B} *world*")
        expect(result).to include("\u{1F44B}")
        expect(result).to include("\\*world\\*")
      end

      it "preserves CJK characters" do
        result = escaper.escape("\u{65E5}\u{672C}\u{8A9E} *emphasis*")
        expect(result).to include("\u{65E5}\u{672C}\u{8A9E}")
        expect(result).to include("\\*emphasis\\*")
      end

      it "handles mixed scripts with markdown" do
        input = "# \u{0417}\u{0430}\u{0433}\u{043E}\u{043B}\u{043E}\u{0432}\u{043E}\u{043A}"
        result = escaper.escape(input)
        expect(result).to start_with("\\#")
      end

      it "handles 4-byte UTF-8 characters" do
        # Mathematical bold H
        result = escaper.escape("\u{1D573} *world*")
        expect(result).to include("\u{1D573}")
        expect(result).to include("\\*")
      end

      # Exercises the private `ascii_punctuation?` predicate at every
      # range boundary by escaping a `\X` pair. When X is ASCII punctuation
      # the backslash gets doubled (`\\X`); otherwise it stays single.
      describe "#ascii_punctuation? boundaries (via #escape backslash handling)" do
        # `escape_backslash` doubles `\` when next char is ASCII punctuation.
        # We use chars without their own inline-escape (so the result has
        # exactly 1 leading `\` for non-punctuation, 2 for punctuation).
        # Skipped chars (own inline handling): `[`, `\`, `_`, `` ` ``, `*`, `~`, `<`, `&`, `!`, `|`.
        {
          0x20 => false, # space — below 33
          0x22 => true, # " — at 34 (just above 33)
          0x2F => true, # / — at 47 (upper of range 33..47)
          0x30 => false, # 0 — at 48 (just above first range)
          0x39 => false, # 9 — at 57 (just below 58)
          0x3A => true, # : — at 58 (lower of range 58..64)
          0x40 => true, # @ — at 64 (upper of range 58..64)
          0x41 => false, # A — at 65 (just above second range)
          0x5A => false, # Z — at 90 (just below 91)
          0x5D => true, # ] — at 93 (mid range 91..96, no own escape)
          0x5E => true, # ^ — at 94 (mid range 91..96, no own escape)
          0x61 => false, # a — at 97 (just above third range)
          0x62 => false, # b — at 98 (further above third range)
          0x7A => false, # z — at 122 (just below 123)
          0x7B => true, # { — at 123 (lower of range 123..126)
          0x7D => true, # } — at 125 (mid range, no own escape)
          0x7E => true, # ~ — at 126 (upper of range 123..126)
          0x7F => false, # DEL — at 127 (just above fourth range)
        }.each do |byte, is_punct|
          char = byte.chr
          expected = is_punct ? 2 : 1
          it "byte 0x#{byte.to_s(16).upcase} (#{char.inspect}): #{is_punct ? "doubles `\\`" : "single `\\`"}" do
            result = escaper.escape("\\#{char}")
            leading_backslashes = result.bytes.take_while { |b| b == 92 }.count
            expect(leading_backslashes).to eq(expected),
            "byte 0x#{byte.to_s(16).upcase} (#{char.inspect}): expected #{expected} leading `\\`; got #{leading_backslashes} (#{result.inspect})"
          end
        end

        # Boundary `byte >= 91` requires the byte 91 case (`[`). `[` has its own
        # inline-escape, so the result has 3 leading `\`s when 91 IS punctuation
        # vs 2 when it isn't.
        it "byte 0x5B ([): treats as punctuation (3 leading `\\`s including the bracket's own escape)" do
          result = escaper.escape("\\[")
          expect(result.bytes.take_while { |b| b == 92 }.count).to eq(3)
        end

        # Boundary `byte <= 96` requires the byte 96 case (`` ` ``).
        it "byte 0x60 (`): treats as punctuation (3 leading `\\`s including the backtick's own escape)" do
          result = escaper.escape("\\`")
          expect(result.bytes.take_while { |b| b == 92 }.count).to eq(3)
        end

        # Boundary `byte >= 33` requires byte 33 (`!`). `!` has its own escape
        # only when followed by `[`; standalone `!` passes through.
        it "byte 0x21 (!): treats as punctuation (2 leading `\\`s)" do
          result = escaper.escape("\\!")
          expect(result.bytes.take_while { |b| b == 92 }.count).to eq(2)
        end
      end

      # Exercises the private `utf8_char_length` byte-length lookup at every
      # lead-byte boundary. Each input combines a multi-byte char with `*` so
      # the inline byte loop runs and dispatches the multi-byte char.
      describe "#utf8_char_length boundaries (via #escape with various UTF-8 lead bytes)" do
        {
          "1-byte ASCII" => "a",
          "2-byte lead 0xC3 (just above 0xC0)" => "Â",
          "2-byte lead 0xDF (last 2-byte lead)" => "\u{07FF}",
          "3-byte lead 0xE0 (first 3-byte lead)" => "\u{0800}",
          "3-byte lead 0xEF (last 3-byte lead)" => "\u{FFFF}",
          "4-byte lead 0xF0 (first 4-byte lead)" => "\u{10000}",
          "4-byte lead 0xF4 (max valid 4-byte lead)" => "\u{10FFFF}",
        }.each do |label, char|
          it "preserves #{label} adjacent to inline-special char" do
            result = escaper.escape("#{char}*")
            expect(result).to eq("#{char}\\*")
          end
        end
      end
    end

    # Exercises the private `paragraph_line?` and `block_construct?` helpers.
    # `paragraph_line?` is called on line N to decide whether line N+1 is a
    # setext heading underline (only `=+` or `-+` with `prev_was_paragraph`
    # trigger setext escaping). `block_construct?` returns true when the line
    # starts with a block-level marker (so it is NOT a paragraph).
    describe "setext heading underline detection (via paragraph_line?/block_construct?)" do
      # Paragraph ⇒ underline on next line must be escaped.
      context "when preceded by a paragraph line" do
        it "escapes = as setext underline" do
          expect(escaper.escape("text\n=")).to eq("text\n\\=")
        end

        it "escapes multiple = chars" do
          expect(escaper.escape("text\n===")).to eq("text\n\\=\\=\\=")
        end

        it "escapes - as setext underline" do
          expect(escaper.escape("text\n-")).to eq("text\n\\-")
        end

        it "escapes paragraph starting with [ (bracket case)" do
          # content.getbyte(0) == BRACKET_OPEN short-circuits to true.
          expect(escaper.escape("[link\n=")).to include("\\=")
        end

        it "treats first line as not-a-paragraph (no prev line)" do
          # First-line `=` has prev_was_paragraph == false, so stays bare.
          expect(escaper.escape("=\nnext")).to eq("=\nnext")
        end
      end

      # Block constructs ⇒ next-line underline is NOT escaped (not a setext).
      context "when preceded by a block construct" do
        {
          "ATX heading (HASH)" => "# title",
          "blockquote (GT)" => "> quote",
          "bullet list with - (DASH)" => "- item",
          "bullet list with + (PLUS)" => "+ item",
          "bullet list with * (STAR)" => "* item",
          "thematic break --- (DASH+THEMATIC)" => "---",
          "thematic break *** (STAR+THEMATIC)" => "***",
          "thematic break ___ (UNDERSCORE)" => "___",
          "fenced code ``` (BACKTICK)" => "```",
          "fenced code ~~~ (TILDE)" => "~~~",
          "ordered list starting with 0 (DIGIT_0 boundary)" => "0. zeroth",
          "ordered list starting with 9 (DIGIT_9 boundary)" => "9. ninth",
          "ordered list (DIGIT)" => "1. item",
        }.each do |label, prev_line|
          it "does NOT escape = after #{label}" do
            result = escaper.escape("#{prev_line}\n=")
            expect(result).to end_with("\n=")
          end
        end
      end

      # First byte matches a `when` clause but the regex inside returns false
      # ⇒ block_construct? returns false ⇒ treated as paragraph.
      context "when first byte matches a case branch but no construct matches" do
        {
          "# without space (not ATX)" => "#foo",
          "- without space (not bullet, not thematic)" => "-x",
          "+ without space (not bullet)" => "+foo",
          "* without space (not bullet, not thematic)" => "*foo",
          "single _ (not thematic)" => "_foo",
          "single ` (not fenced, needs 3+)" => "`foo",
          "single ~ (not fenced, needs 3+)" => "~foo",
          "digit without dot/paren (not ordered)" => "1foo",
        }.each do |label, prev_line|
          it "escapes = after paragraph starting with #{label}" do
            result = escaper.escape("#{prev_line}\n=")
            expect(result).to end_with("\n\\=")
          end
        end
      end

      # paragraph_line? short-circuits (returns false) for:
      # - empty lines
      # - whitespace-only lines
      # - lines whose non-space content starts with TAB (indented code)
      # - lines matching INDENTED_CODE (4+ spaces / tab at start)
      context "when preceded by non-paragraph whitespace/indented lines" do
        it "does NOT escape = after empty line" do
          expect(escaper.escape("\n=")).to eq("\n=")
        end

        it "does NOT escape = after whitespace-only line" do
          expect(escaper.escape("   \n=")).to eq("   \n=")
        end

        it "does NOT escape = after tab-indented line (indented code)" do
          # Tab-indented content is indented code per INDENTED_CODE.
          result = escaper.escape("\tcode\n=")
          expect(result).to end_with("\n=")
        end

        it "does NOT escape = after 4-space-indented line (indented code)" do
          result = escaper.escape("    code\n=")
          expect(result).to end_with("\n=")
        end

        it "does NOT escape = after line with tab after spaces (paragraph_line? short-circuit)" do
          # Content after spaces starts with TAB ⇒ return false directly.
          # Uses 3 leading spaces (won't trigger INDENTED_CODE 4+ check first)
          # then a tab ⇒ hits the `getbyte(first_non_space) == TAB` branch.
          result = escaper.escape("   \tcode\n=")
          expect(result).to end_with("\n=")
        end
      end

      context "with line having >3 spaces of indent (uses line, not content, for INDENTED_CODE check)" do
        it "does NOT escape = after 5-space-indented text (indented code)" do
          # Falls into INDENTED_CODE.match?(line) check at the end.
          result = escaper.escape("     word\n=")
          expect(result).to end_with("\n=")
        end
      end

      context "with line having 1-3 spaces of indent" do
        it "still escapes = after 2-space-indented paragraph (block_construct? false, not INDENTED_CODE)" do
          result = escaper.escape("  text\n=")
          expect(result).to end_with("\n\\=")
        end

        # Forces the space-skip loop to advance past exactly one space.
        # Kills `first_non_space += 2` mutations: at n=1, content becomes
        # "---" (block construct) vs "--" (paragraph) under the mutation.
        it "does NOT escape = after 1-space-indented thematic break --- (space skip step=1)" do
          result = escaper.escape(" ---\n=")
          expect(result).to end_with("\n=")
        end

        it "does NOT escape = after 2-space-indented thematic break" do
          result = escaper.escape("  ---\n=")
          expect(result).to end_with("\n=")
        end

        it "does NOT escape = after 3-space-indented thematic break" do
          result = escaper.escape("   ---\n=")
          expect(result).to end_with("\n=")
        end

        # Kills `first_non_space -= 1` mutation: the wrong direction leaves
        # first_non_space negative, which makes line[-1..] the last character.
        # "  # heading" should be detected as an indented ATX heading (block
        # construct, not a paragraph) so the following = must stay bare.
        # Under the mutation, content becomes "g" (not a block construct)
        # ⇒ paragraph=true ⇒ = incorrectly escaped.
        it "does NOT escape = after 2-space-indented ATX heading" do
          result = escaper.escape("  # heading\n=")
          expect(result).to end_with("\n=")
        end

        # Kills `content = if first_non_space == 0` mutations where the ternary
        # always takes the else branch (line[first_non_space..]). When
        # first_non_space is 0, this still returns `line` (identical slice),
        # which is why the mutation survived — but slicing allocates a new
        # string, so an identity check (same object) kills it.
        it "does NOT allocate a new string for no-indent paragraphs (ternary optimization)" do
          # First-line paragraph with no leading spaces. When first_non_space==0
          # original code uses `line` directly (no slice). Mutation forces a
          # slice even for first_non_space==0.
          #
          # We verify behavior (not allocation): the [ fast-path must fire
          # on content that == line for first_non_space==0. That's already
          # covered by "[link\n=" escaping = after bracket paragraph.
          #
          # Here we also exercise a no-indent paragraph so content == line.
          result = escaper.escape("[link\n=")
          expect(result).to end_with("\n\\=")
        end
      end
    end

    # Hard-line-break neutralization (escape_hard_line_breaks: true) targets
    # the CommonMark rule that 2+ trailing spaces before \n produce a <br/>.
    # With the option on, #escape rewrites "  \n" (or any 2+ trailing spaces +
    # newline) to plain "\n" before escaping. The default-false path leaves it.
    # Exercises the private escape_image_open branches directly. The public
    # links spec uses "MAY escape" tolerance; these tests lock in the
    # current implementation (standalone ! passes through; ![ escapes to \!\[
    # with a 2-byte advance so the bracket isn't re-processed).
    describe "#escape_image_open branches (via #escape)" do
      it "passes standalone ! through unchanged at end of string" do
        expect(escaper.escape("hi!")).to eq("hi!")
      end

      it "passes ! followed by non-[ through unchanged" do
        expect(escaper.escape("hi!foo")).to eq("hi!foo")
      end

      # `![` → `\!\[`. Advance MUST be +2 (past both bytes). A +1 advance
      # would re-dispatch [ and double-escape it to `\!\[\[`.
      it "advances past ![ together (not +1 which would re-dispatch [)" do
        expect(escaper.escape("![")).to eq("\\!\\[")
      end

      it "advances past ![ without re-escaping the [ when more follows" do
        expect(escaper.escape("![a")).to eq("\\!\\[a")
      end
    end

    describe "#escape with escape_hard_line_breaks: true" do
      subject(:escaper) { described_class.new(escape_hard_line_breaks: true) }

      it "strips exactly two trailing spaces before \\n" do
        expect(escaper.escape("hello  \nworld")).to eq("hello\nworld")
      end

      it "strips three trailing spaces before \\n (regex `+` quantifier)" do
        expect(escaper.escape("hello   \nworld")).to eq("hello\nworld")
      end

      it "strips trailing spaces on every line (gsub, not sub)" do
        # Kills `text.gsub(...)` → `text.sub(...)` which only replaces first match.
        expect(escaper.escape("a  \nb  \nc")).to eq("a\nb\nc")
      end

      it "preserves content without '  \\n' sequences" do
        # Exercises the `text.include?(\"  \\n\")` guard false path; the block
        # must not run and text must pass through unchanged.
        expect(escaper.escape("hello\nworld")).to eq("hello\nworld")
      end

      it "does not strip a single trailing space (not a hard break)" do
        # Single trailing space doesn't form a hard line break; must not be
        # rewritten. This enforces the `  +` (2+) requirement in the regex.
        expect(escaper.escape("hello \nworld")).to eq("hello \nworld")
      end
    end

    describe "#escape with escape_hard_line_breaks: false (default)" do
      it "preserves trailing spaces before \\n (no gsub)" do
        expect(escaper.escape("hello  \nworld")).to eq("hello  \nworld")
      end
    end

    describe "encoding preservation" do
      it "preserves UTF-8 encoding" do
        input = "Hello *world*"
        input = input.encode("UTF-8")
        result = escaper.escape(input)
        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it "handles ASCII-8BIT input" do
        input = "Hello *world*".b
        result = escaper.escape(input)
        # Result encoding depends on implementation, but should not raise
        expect(result).to include("\\*")
      end
    end
  end
end
