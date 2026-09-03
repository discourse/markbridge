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

    # A line that contains only `=` is a setext heading underline when a
    # paragraph line comes before it. The escaper only sees one text
    # fragment and cannot know what the renderer puts in front of it, so
    # it escapes such a line in every position. Discourse renders `\=` as
    # a literal `=`, so the extra backslashes do not change the result.
    describe "setext heading underline escaping" do
      it "escapes a single = on the first line" do
        expect(escaper.escape("=")).to eq("\\=")
      end

      it "escapes several = on the first line" do
        expect(escaper.escape("===")).to eq("\\=\\=\\=")
      end

      it "escapes a =-only first line followed by text" do
        expect(escaper.escape("===\nText")).to eq("\\=\\=\\=\nText")
      end

      it "escapes = after a paragraph line" do
        expect(escaper.escape("text\n=")).to eq("text\n\\=")
      end

      it "escapes = after a paragraph line starting with [" do
        expect(escaper.escape("[link\n=")).to eq("\\[link\n\\=")
      end

      {
        "an empty line" => "",
        "a blank line with spaces" => "   ",
        "a bullet list item" => "- item",
        "an ATX heading" => "# title",
        "a blockquote line" => "> quote",
        "a thematic break" => "---",
        "a fenced code marker" => "```",
        "an ordered list item" => "1. item",
        "indented code" => "    code",
        "a tab-indented line" => "\tcode",
      }.each do |label, prev_line|
        it "escapes a =-only line after #{label}" do
          expect(escaper.escape("#{prev_line}\n===")).to end_with("\n\\=\\=\\=")
        end
      end

      it "escapes a =-only line with trailing spaces" do
        expect(escaper.escape("===  ")).to eq("\\=\\=\\=  ")
      end

      it "escapes a =-only line with a trailing tab" do
        expect(escaper.escape("===\t")).to eq("\\=\\=\\=\t")
      end

      it "escapes a =-only line indented by up to 3 spaces" do
        expect(escaper.escape("   ===")).to eq("   \\=\\=\\=")
      end

      it "does not escape = followed by text" do
        expect(escaper.escape("=foo")).to eq("=foo")
      end

      it "does not escape = in the middle of a line" do
        expect(escaper.escape("a === b")).to eq("a === b")
      end

      it "does not escape = when a word follows on the same line" do
        expect(escaper.escape("=== alone")).to eq("=== alone")
      end

      # A `-`-only line never needed a setext rule of its own: a single
      # dash is a bullet list marker, two dashes are the ndash pair that
      # `escape_inline` handles, and three or more are a thematic break.
      # All three rules escape the line already.
      it "escapes a single - line as a bullet marker" do
        expect(escaper.escape("text\n-")).to eq("text\n\\-")
      end

      it "escapes a -- line as an ndash pair" do
        expect(escaper.escape("text\n--")).to eq("text\n\\-\\-")
      end

      it "escapes a --- line as a thematic break" do
        expect(escaper.escape("text\n---")).to eq("text\n\\-\\-\\-")
      end
    end

    # Hard-line-break neutralization (escape_hard_line_breaks: true) targets
    # the CommonMark rule that 2+ trailing spaces before \n produce a <br/>.
    # With the option on, #escape rewrites "  \n" (or any 2+ trailing spaces +
    # newline) to plain "\n" before escaping. The default-false path leaves it.
    # The #escape fast-path returns `text` unchanged (same object, no
    # allocation) when the input has no special characters and no indented
    # code. The slow path through escape_text always allocates a new String
    # (via split + escape_line). Object identity is the observable difference
    # — the `return text` keyword can't be dropped without allocation.
    describe "#escape fast-path allocation contract" do
      it "returns the input String (same object) when no special characters are present" do
        input = "The quick brown fox jumps over the lazy dog"
        expect(escaper.escape(input)).to equal(input)
      end

      it "returns multi-line plain input as the same object (the MAYBE_SPECIAL gate must hold)" do
        # Multi-line matters: escape_text's single-line fast path also
        # preserves object identity, so only a multi-line input can tell
        # the MAYBE_SPECIAL gate apart from an unconditional escape_text
        # (which splits and rebuilds, returning an equal but new String).
        input = "the quick brown fox\njumps over the lazy dog"
        expect(escaper.escape(input)).to equal(input)
      end

      it "returns a NEW string when the input contains any special character" do
        input = "hello *world*"
        expect(escaper.escape(input)).not_to equal(input)
      end

      it "returns the input String (same object) when its specials turn out benign on a single line" do
        # `.` and `)` pass the MAYBE_SPECIAL pre-check but produce no
        # escapes; the single-line fast path must hand back the input
        # itself instead of a split-off copy.
        input = "version 1.2 (beta)"
        expect(escaper.escape(input)).to equal(input)
      end

      it "accepts frozen single-line input whose specials turn out benign" do
        input = "version 1.2 (beta)"
        expect(escaper.escape(input.freeze)).to eq(input)
      end

      it "escapes frozen single-line input" do
        expect(escaper.escape("*bold*".freeze)).to eq("\\*bold\\*")
      end

      it "escapes frozen multi-line input" do
        expect(escaper.escape("# heading\n*bold*".freeze)).to eq("\\# heading\n\\*bold\\*")
      end

      it "returns a NEW string when the input contains indented code" do
        # Tab at line start triggers MAYBE_INDENTED_CODE even with no
        # MAYBE_SPECIAL chars elsewhere.
        input = "foo\n\tbar"
        expect(escaper.escape(input)).not_to equal(input)
      end

      it "returns empty string for nil input (allocation fresh)" do
        expect(escaper.escape(nil)).to eq("")
      end

      # Same identity trick for the hard-line-break guard. When the option
      # is on but the text has no "  \n" sequence, the gsub is skipped and
      # text stays the same object. Mutations that drop the include? guard
      # would force gsub (which always allocates, even with no matches).
      it "with escape_hard_line_breaks=true, returns input unchanged when no '  \\n' sequence exists" do
        escaper_hlb = described_class.new(escape_hard_line_breaks: true)
        input = "nothing needs escaping here"
        expect(escaper_hlb.escape(input)).to equal(input)
      end
    end

    # Kills `ENTITY_REF.match(remaining)` → `remaining` mutation. The public
    # entity_refs spec tolerates either-or behavior for non-entity `&`; this
    # locks in the current implementation (standalone & passes through, only
    # valid entities get the leading backslash).
    describe "#escape_amp branches (via #escape)" do
      it "passes standalone & through unchanged (no entity follows)" do
        expect(escaper.escape("AT&T")).to eq("AT&T")
      end
    end

    # Locks in the "fall through to inline path" behavior for block-level
    # dashes/stars that are neither thematic breaks nor bullet lists.
    # The public bullet_lists/thematic_breaks specs tolerate either-or here;
    # these tests kill `if true` / dropped-guard mutations on the thematic
    # branch that would otherwise force the thematic escape for non-thematic
    # content.
    describe "#escape_block_dash and #escape_block_star fall-through (via #escape)" do
      it "does not apply the thematic-break escape to a single dash before text" do
        # "-foo" — not a bullet (no space after), not a thematic break.
        # Falls through to inline; DASH at line start with non-DASH next is
        # passed through as a bare `-`.
        expect(escaper.escape("-foo")).to eq("-foo")
      end

      # Kills mutations that drop the `THEMATIC_BREAK_DASH.match?` guard in
      # escape_block_dash (`if true`, `if content`). `-foo` is neither a
      # thematic break nor a bullet list, so it has to reach the inline
      # path and come out as a bare `-foo`; under the mutation it would be
      # escaped as `\-foo`. The multi-line input also covers the branch on
      # a line that is not the first one.
      it "does not thematic-escape a dash-prefixed line (regex must still apply)" do
        expect(escaper.escape("text\n-foo")).to eq("text\n-foo")
      end

      it "does not apply the thematic-break escape to a single star before text" do
        expect(escaper.escape("*foo")).to eq("\\*foo")
      end

      # Kills mutations that drop the `SETEXT_UNDERLINE_EQUALS.match?` guard
      # (`if true`, `if content`). `=foo` is not a setext underline, so it
      # must stay bare — `=` is not in INLINE_SPECIAL either. Under the
      # mutation the line would come out as `\=foo`.
      it "does not setext-escape a =-prefixed line (regex must still apply)" do
        expect(escaper.escape("text\n=foo")).to eq("text\n=foo")
      end
    end

    # Locks in the "fall through to inline path" behavior for block-level
    # markers that are not valid block constructs. The public specs allow
    # either-or here; these strict tests kill mutations that unconditionally
    # apply the block escape (`if true`, dropped guards, unconditional
    # `return escape_first_char_inline`).
    describe "#escape_block_level non-construct fall-through (via #escape)" do
      # `#notheading` — # not followed by space/tab/end-of-line is NOT an
      # ATX heading. Original falls through; inline doesn't escape # (not in
      # INLINE_SPECIAL). Output is bare.
      it "does not escape # without following space" do
        expect(escaper.escape("#notheading")).to eq("#notheading")
      end

      # `+foo` — + not followed by space is NOT a bullet list marker.
      # Original falls through; + is not in INLINE_SPECIAL. Output is bare.
      it "does not escape + without following space" do
        expect(escaper.escape("+foo")).to eq("+foo")
      end
    end

    # Exercises the three escape_lt branches (autolink / HTML tag / bare <)
    # and the pos-advance math. The html_spec covers simple inputs; these
    # add cases where a mutation would only change output for specific
    # content (inline specials inside autolink, surrounding content, or
    # multiple backticks inside an HTML tag).
    describe "#escape_lt branches (via #escape)" do
      # `AUTOLINK.match(remaining)` → `nil`: autolink check fails, falls to
      # else. If autolink contains inline specials, those would be escaped
      # in the mutated version but preserved in the original.
      it "preserves inline specials inside an autolink URL" do
        expect(escaper.escape("<http://example.com/path*with*stars>")).to eq(
          "<http://example.com/path*with*stars>",
        )
      end

      # `pos + matched.bytesize` → `matched.bytesize`: the return value
      # advances to match length instead of past the match, causing main
      # loop to re-process bytes. Tests with content before the autolink
      # expose the wrong advance.
      it "advances past autolink without re-processing matched bytes" do
        expect(escaper.escape("foo<http://x>bar")).to eq("foo<http://x>bar")
      end

      # `gsub` → `sub` in the HTML-tag backtick escape: only first backtick
      # is escaped under mutation. Need ≥2 backticks in the tag attribute.
      it "escapes every backtick in an HTML tag attribute (gsub not sub)" do
        expect(escaper.escape('<a title="`a` `b`">')).to eq('\\<a title="\\`a\\` \\`b\\`">')
      end
    end

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

    describe "ordered-list inline escaping" do
      # Kills `escape_inline(rest)` → `rest` in escape_block_ordered_list.
      # The rest of the line after the marker still contains inline
      # specials which must be escaped before the tuple returns
      # skip_inline=true.
      it "escapes inline specials after an ordered-list marker" do
        expect(escaper.escape("1. *bold*")).to eq("1\\. \\*bold\\*")
      end

      it "escapes inline specials after a paren-style ordered marker" do
        expect(escaper.escape("2) text_with_emphasis")).to eq("2\\) text\\_with\\_emphasis")
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
