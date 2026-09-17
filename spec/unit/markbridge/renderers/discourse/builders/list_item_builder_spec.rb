# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Builders::ListItemBuilder do
  let(:builder) { described_class.new }

  describe "#build" do
    context "with single-line content" do
      it "formats unordered list item" do
        result = builder.build("simple text", marker: "- ", indent: "")
        expect(result).to eq("- simple text\n")
      end

      it "formats ordered list item" do
        result = builder.build("simple text", marker: "1. ", indent: "")
        expect(result).to eq("1. simple text\n")
      end

      it "applies indentation" do
        result = builder.build("nested item", marker: "- ", indent: "  ")
        expect(result).to eq("  - nested item\n")
      end

      it "applies multiple levels of indentation" do
        result = builder.build("deep item", marker: "1. ", indent: "     ")
        expect(result).to eq("     1. deep item\n")
      end
    end

    context "with multi-line content" do
      it "indents continuation lines for unordered list" do
        result = builder.build("line1\nline2\nline3", marker: "- ", indent: "")
        expect(result).to eq("- line1\n  line2\n  line3\n")
      end

      it "indents continuation lines for ordered list" do
        result = builder.build("line1\nline2\nline3", marker: "1. ", indent: "")
        expect(result).to eq("1. line1\n  line2\n  line3\n")
      end

      it "applies base indentation to all lines" do
        result = builder.build("line1\nline2", marker: "- ", indent: "  ")
        expect(result).to eq("  - line1\n    line2\n")
      end

      it "handles deeply nested multi-line content" do
        result = builder.build("first\nsecond", marker: "1. ", indent: "     ")
        expect(result).to eq("     1. first\n       second\n")
      end
    end

    context "with blank lines (paragraph breaks)" do
      it "preserves blank lines within text content" do
        result = builder.build("First paragraph\n\nSecond paragraph", marker: "- ", indent: "")
        expect(result).to eq("- First paragraph\n  \n  Second paragraph\n")
      end

      it "preserves blank lines with indentation" do
        result = builder.build("Para 1\n\nPara 2", marker: "- ", indent: "  ")
        expect(result).to eq("  - Para 1\n    \n    Para 2\n")
      end

      it "preserves multiple blank lines" do
        result = builder.build("Text\n\n\nMore text", marker: "- ", indent: "")
        expect(result).to eq("- Text\n  \n  \n  More text\n")
      end
    end

    context "with nested list items" do
      it "does not add extra indentation to nested list markers" do
        content = "parent text\n  - nested item"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- parent text\n  - nested item\n")
      end

      it "detects ordered list markers" do
        content = "parent\n  1. nested"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- parent\n  1. nested\n")
      end

      it "handles nested lists with base indentation" do
        content = "text\n    - deep nested"
        result = builder.build(content, marker: "1. ", indent: "  ")
        expect(result).to eq("  1. text\n    - deep nested\n")
      end

      it "skips blank lines before nested list items" do
        content = "parent text\n\n  - nested item"
        result = builder.build(content, marker: "- ", indent: "")
        # Blank line before nested list is structural, not content, so it's skipped
        expect(result).to eq("- parent text\n  - nested item\n")
      end

      # A blank line after an HTML block opener is what closes the block
      # (CommonMark 4.6) — it outranks the structural-blank rule above.
      # Dropping it would leave the nested list inside the open block,
      # where it cooks as literal text rather than a list.
      it "keeps a blank line before a nested list when it closes an HTML block" do
        content = %(parent text\n\n<div align="center">\n\n  - nested item)
        result = builder.build(content, marker: "- ", indent: "")

        expect(result).to eq(%(- parent text\n  \n  <div align="center">\n  \n  - nested item\n))
      end

      it "keeps that blank line at a deeper indentation level too" do
        content = %(parent\n\n<div align="center">\n\n    - nested item)
        result = builder.build(content, marker: "- ", indent: "  ")

        expect(result).to eq(
          %(  - parent\n    \n    <div align="center">\n    \n    - nested item\n),
        )
      end

      # An autolink is not a tag, so it opens no HTML block and the blank
      # before the nested list stays structural. Keeping it would turn the
      # whole surrounding list loose.
      it "skips the structural blank after an autolink" do
        content = %(<https://example.com>\n\n  - child)
        result = builder.build(content, marker: "- ", indent: "")

        expect(result).to eq(%(- <https://example.com>\n  - child\n))
      end

      # `span` is not a CommonMark block tag, and the tag is not alone on
      # the line, so no HTML block opens here either.
      it "skips the structural blank after inline HTML that opens no block" do
        content = %(<span style="color: red">red</span>\n\n  - child)
        result = builder.build(content, marker: "- ", indent: "")

        expect(result).to eq(%(- <span style="color: red">red</span>\n  - child\n))
      end

      it "keeps the blank after a block-level tag that is not a div" do
        content = %(<p>para</p>\n\n  - child)
        result = builder.build(content, marker: "- ", indent: "")

        expect(result).to eq(%(- <p>para</p>\n  \n  - child\n))
      end

      # A line a nested build already placed at its absolute column must
      # not be indented again: each extra pass pushes it a level deeper
      # than the list items it sits among, and past four columns a code
      # fence turns into an indented code block.
      it "does not re-indent a line already at the continuation column" do
        result = builder.build(%(text\n    already placed), marker: "- ", indent: "  ")

        expect(result).to eq(%(  - text\n    already placed\n))
      end

      # Code bypasses the escaper, so its leading spaces reach the builder
      # as real spaces rather than NBSPs. They are content: indenting the
      # fence but not its body, or vice versa, silently rewrites the code.
      it "keeps code indented relative to a fence it re-indents" do
        result = builder.build(%(parent\n\n```\n  x\nend\n```), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ```\n    x\n  end\n  ```\n))
      end

      # A blank line inside a code block is part of the code. Outside a
      # fence a blank before a list marker is dropped as structural, so
      # the fence has to stay in force even when it needed no re-indenting.
      it "keeps a blank line inside an already-placed fence" do
        result =
          builder.build(
            %(parent\n\n    ```\n    x\n\n    - item\n    ```),
            marker: "- ",
            indent: "  ",
          )

        expect(result).to eq(%(  - parent\n    \n    ```\n    x\n\n    - item\n    ```\n))
      end

      it "leaves code alone when the fence is already placed" do
        result = builder.build(%(parent\n\n    ```\n      x\n    ```), marker: "- ", indent: "  ")

        expect(result).to eq(%(  - parent\n    \n    ```\n      x\n    ```\n))
      end

      # A line inside a fence is code, whatever it looks like. Read as a
      # list marker it would be passed through unindented and fall out of
      # the code block.
      it "indents a line inside a fence even when it looks like a list item" do
        result = builder.build(%(parent\n\n```\n  x\n- not a list\n```), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ```\n    x\n  - not a list\n  ```\n))
      end

      # ...and once the closing fence is seen, normal handling resumes: a
      # real nested list after the block keeps its own placement.
      it "resumes normal handling after the closing fence" do
        result = builder.build(%(parent\n\n```\nx\n```\n\n  - nested), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ```\n  x\n  ```\n  - nested\n))
      end

      # `build` folds the item's first line into the marker line, so a
      # fence opening there is never seen by the continuation loop unless
      # the tracking is seeded from it.
      it "tracks a fence that opens on the item's own first line" do
        result = builder.build(%(```\n  x\n```), marker: "- ", indent: "")

        expect(result).to eq(%(- ```\n    x\n  ```\n))
      end

      # A fence closes only on its own delimiter (CommonMark 4.5), so the
      # backticks CodeTag wrapped in tildes are code, not a closing fence.
      it "does not close a tilde fence on a backtick line" do
        result = builder.build(%(parent\n\n~~~\n```ruby\n  x\n```\n~~~), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ~~~\n  ```ruby\n    x\n  ```\n  ~~~\n))
      end

      it "does not close a backtick fence on a tilde line" do
        result = builder.build(%(parent\n\n```\n~~~\n  x\n~~~\n```), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ```\n  ~~~\n    x\n  ~~~\n  ```\n))
      end

      # A closing run must be at least as long as the opening one.
      it "does not close a longer fence with a shorter run" do
        result = builder.build(%(parent\n\n````\n```\n  x\n```\n````), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ````\n  ```\n    x\n  ```\n  ````\n))
      end

      it "closes a fence whose opener carries an info string" do
        result = builder.build(%(parent\n\n```ruby\n  x\n```), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ```ruby\n    x\n  ```\n))
      end

      # The delimiter is matched against the run alone, not the run plus
      # the whitespace in front of it, so an indented fence still closes
      # and normal handling resumes for what follows.
      it "closes an indented fence and resumes normal handling after it" do
        result =
          builder.build(%(parent\n\n    ```\n      x\n    ```\nafter), marker: "- ", indent: "  ")

        expect(result).to eq(%(  - parent\n    \n    ```\n      x\n    ```\n    after\n))
      end

      # The nested list after the block is the tell: still inside a fence
      # it would be indented as code rather than left at its own level.
      it "closes a fence with a run longer than the one that opened it" do
        result = builder.build(%(parent\n\n```\n  x\n````\n\n  - item), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ```\n    x\n  ````\n  - item\n))
      end

      # Tilde mirror of the run-length rules, with the inner short run
      # indented: neither its length nor the whitespace around it may be
      # mistaken for the four tildes that opened the block.
      it "does not close a four-tilde fence on an indented three-tilde line" do
        result =
          builder.build(%(parent\n\n~~~~\n  ~~~\n  x\n~~~~\n\n  - item), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ~~~~\n    ~~~\n    x\n  ~~~~\n  - item\n))
      end

      # A closing fence carries nothing but its run; a line with an info
      # string after it is code.
      it "does not close a fence on a delimiter line that carries text" do
        result = builder.build(%(parent\n\n```\n```ruby\n  x\n```\nafter), marker: "- ", indent: "")

        expect(result).to eq(%(- parent\n  \n  ```\n  ```ruby\n    x\n  ```\n  after\n))
      end

      # A nested item whose content starts with a fence arrives as
      # `- ``` `. Miss that opener and the block's own closing fence is
      # read as an opener instead, leaving tracking on for good: whatever
      # follows the nested block is passed through unindented and falls
      # out of the item.
      it "recognizes a fence opened on a nested list-marker line" do
        result = builder.build(%(outer\n  - ```\n    x\n    ```\nafter), marker: "- ", indent: "")

        expect(result).to eq(%(- outer\n  - ```\n    x\n    ```\n  after\n))
      end

      # Markers stack as nesting deepens, so the opener can sit behind
      # more than one of them.
      it "recognizes a fence behind two nested markers" do
        result = builder.build(%(o\n  - - ```\n      x\n      ```\nafter), marker: "- ", indent: "")

        expect(result).to eq(%(- o\n  - - ```\n      x\n      ```\n  after\n))
      end

      it "recognizes one opened on an ordered nested marker line" do
        result = builder.build(%(outer\n  1. ```\n    x\n    ```\nafter), marker: "- ", indent: "")

        expect(result).to eq(%(- outer\n  1. ```\n    x\n    ```\n  after\n))
      end

      it "recognizes a tilde fence on a nested marker line" do
        result = builder.build(%(outer\n  - ~~~\n    x\n    ~~~\nafter), marker: "- ", indent: "")

        expect(result).to eq(%(- outer\n  - ~~~\n    x\n    ~~~\n  after\n))
      end

      # An inline ```code``` span is not a fence: a backtick fence's info
      # string may not contain a backtick (CommonMark 4.5).
      it "does not read an inline backtick span on a marker line as a fence" do
        result = builder.build(%(outer\n  - ```x```\nafter), marker: "- ", indent: "")

        expect(result).to eq(%(- outer\n  - ```x```\n  after\n))
      end

      # The backtick rule is specific to backtick fences: a tilde fence's
      # info string may contain backticks, so this one still opens.
      it "opens a tilde fence whose info string contains a backtick" do
        result =
          builder.build(%(outer\n  - ~~~`x`\n    y\n    ~~~\nafter), marker: "- ", indent: "")

        expect(result).to eq(%(- outer\n  - ~~~`x`\n    y\n    ~~~\n  after\n))
      end

      it "still skips the structural blank when the line before is plain text" do
        content = %(parent text\n\nnot html\n\n  - nested item)
        result = builder.build(content, marker: "- ", indent: "")

        expect(result).to eq("- parent text\n  \n  not html\n  - nested item\n")
      end
    end

    context "with complex mixed content" do
      it "handles text, blank lines, and nested lists together" do
        content = "First line\n\nSecond line\n  - nested\nThird line"
        result = builder.build(content, marker: "- ", indent: "")
        # Text after nested list still gets continuation indent
        expect(result).to eq("- First line\n  \n  Second line\n  - nested\n  Third line\n")
      end

      it "handles ordered parent with unordered nested" do
        content = "ordered parent\n   - unordered nested\nmore parent"
        result = builder.build(content, marker: "1. ", indent: "")
        # Text after nested list still gets continuation indent
        expect(result).to eq("1. ordered parent\n   - unordered nested\n  more parent\n")
      end

      it "preserves exact indentation of nested items" do
        content = "text\n     - deeply indented nested"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- text\n     - deeply indented nested\n")
      end
    end

    context "with blank lines around nested list items" do
      # Kills `[idx + 1]` → `[idx - 1]` / `[1]` / `[-1]` mutations in
      # handle_empty_line. Requires a blank line whose PREVIOUS line
      # is a nested list marker but whose NEXT line is plain text.
      # Under `[idx - 1]` the mutation would look backward at the
      # nested marker and skip the blank; original looks forward at
      # plain text and preserves the paragraph-break indent.
      it "preserves blank line after nested list when followed by plain text" do
        content = "parent\n  - nested\n\nafter"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- parent\n  - nested\n  \n  after\n")
      end

      # Kills `\d+\.` → `\d\.` mutation on the nested-list regex in
      # format_continuation_line / handle_empty_line. Multi-digit
      # ordered marker (`10.`) only matches with `\d+`, not `\d`.
      it "detects multi-digit ordered-list markers as nested" do
        content = "parent\n  10. tenth"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- parent\n  10. tenth\n")
      end

      # Kills `\A\s*` → `\A\s+` mutation on the nested-list regex.
      # An unindented marker as a continuation line is atypical but
      # the regex was written to allow zero leading whitespace; the
      # mutation requires at least one.
      it "treats unindented list marker in continuation as nested (zero leading space)" do
        content = "text\n- unindented"
        result = builder.build(content, marker: "- ", indent: "")
        # Under \A\s+ the line would get continuation_indent prepended
        # instead of being kept as-is.
        expect(result).to eq("- text\n- unindented\n")
      end

      # Kills `continuation_lines[idx + 1]` → `continuation_lines[1]`
      # mutation. Requires the blank line at idx > 0 where `[1]` gives
      # a different element than `[idx + 1]`. With blank at idx=1,
      # `[1]` would be the blank itself (no match → preserve indent),
      # while `[idx + 1]` points to the nested marker (match → skip).
      it "skips blank line at idx>0 when followed by nested marker (forward lookup)" do
        content = "a\nb\n\n  - nested\nc"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- a\n  b\n  - nested\n  c\n")
      end

      # Kills `\A\s*` → `\A\s+` mutation on handle_empty_line's regex.
      # Next line is an unindented nested marker (zero leading space);
      # `\s+` would require at least one space and fail to match.
      it "skips blank line before unindented nested marker" do
        content = "a\n\n- nested"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- a\n- nested\n")
      end

      # Kills `(?:-|\d+\.)` → `(?:-)` / `\d\.` / `\D+\.` mutations.
      # Blank line before a multi-digit ordered-marker nested item.
      # `\d` (single) would fail to match `10.`. `\D+` would require
      # non-digits. `(?:-)` drops ordered entirely.
      it "skips blank line before multi-digit ordered nested marker" do
        content = "a\n\n  10. nested"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- a\n  10. nested\n")
      end
    end

    context "with edge cases" do
      it "handles empty content" do
        result = builder.build("", marker: "- ", indent: "")
        expect(result).to eq("- \n")
      end

      it "handles content that is only whitespace" do
        result = builder.build("   ", marker: "- ", indent: "")
        expect(result).to eq("-    \n")
      end

      it "handles content that is only newlines" do
        result = builder.build("\n\n", marker: "- ", indent: "")
        # Empty content with only newlines is treated as empty
        expect(result).to eq("- \n")
      end

      it "handles very long indentation" do
        long_indent = "          "
        result = builder.build("text", marker: "- ", indent: long_indent)
        expect(result).to eq("#{long_indent}- text\n")
      end
    end
  end
end
