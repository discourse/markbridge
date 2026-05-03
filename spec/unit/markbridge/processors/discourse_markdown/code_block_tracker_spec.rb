# frozen_string_literal: true

RSpec.describe Markbridge::Processors::DiscourseMarkdown::CodeBlockTracker do
  subject(:tracker) { described_class.new }

  describe "#in_code?" do
    it "returns false initially" do
      expect(tracker.in_code?).to be false
    end

    it "returns true when in fenced block" do
      input = "```\ncode\n```"
      tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(tracker.in_code?).to be true
    end

    it "returns true when in inline code" do
      input = "`code`"
      tracker.check_inline_boundary(input, 0)

      expect(tracker.in_code?).to be true
    end

    it "returns true when in indented block" do
      input = "    code"
      tracker.check_indented_boundary(input, 0, line_start: true)

      expect(tracker.in_code?).to be true
    end
  end

  describe "#check_fenced_boundary" do
    it "detects opening fence with backticks" do
      input = "```\ncode\n```"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to eq(4) # After "```\n"
      expect(tracker.in_fenced_block).to be true
    end

    it "detects opening fence with tildes" do
      input = "~~~\ncode\n~~~"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to eq(4)
      expect(tracker.in_fenced_block).to be true
    end

    # Kills mutations that drop or loosen the `fence_char == "`" ||
    # fence_char == "~"` guard. Without that guard, any repeated
    # non-fence character at line start (e.g. "aaa") would be counted
    # by count_fence_chars and mis-identified as an opening fence.
    it "does not open a fence with non-backtick/tilde characters" do
      input = "aaaaaa not a fence\n"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be false
    end

    it "does not open a fence with repeated hash characters" do
      input = "#### heading-like\n"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be false
    end

    # Kills mutations on the `fence_length < 3` guard (< 2, < 1, < 0).
    # 1 and 2 backtick / tilde sequences must NOT open a fence.
    it "does not open a fence with fewer than 3 backticks" do
      input = "``not a fence\n"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be false
    end

    it "does not open a fence with a single backtick at line start" do
      input = "`inline`"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be false
    end

    it "does not open a fence with fewer than 3 tildes" do
      input = "~~not a fence\n"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be false
    end

    it "allows up to 3 spaces of indentation" do
      input = "   ```\ncode\n```"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to eq(7) # After "   ```\n"
      expect(tracker.in_fenced_block).to be true
    end

    it "ignores fence with 4+ spaces of indentation" do
      input = "    ```\ncode\n```"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be false
    end

    it "requires line_start to be true" do
      input = "text ```\ncode\n```"
      new_pos = tracker.check_fenced_boundary(input, 5, line_start: false)

      expect(new_pos).to be_nil
    end

    it "detects closing fence" do
      input = "```\ncode\n```"
      # Open
      tracker.check_fenced_boundary(input, 0, line_start: true)
      expect(tracker.in_fenced_block).to be true

      # Close
      new_pos = tracker.check_fenced_boundary(input, 9, line_start: true)
      expect(new_pos).to eq(12)
      expect(tracker.in_fenced_block).to be false
    end

    # Kills mutations on the `scan_pos >= input_length || input[scan_pos]
    # == "\n"` branch. With more content after the closing fence + \n,
    # the \n arm is what closes the fence (the `>= input_length` arm
    # only fires at actual EOF).
    it "detects closing fence followed by a newline and more content" do
      input = "```\ncode\n```\ntrailing"
      tracker.check_fenced_boundary(input, 0, line_start: true)

      new_pos = tracker.check_fenced_boundary(input, 9, line_start: true)
      expect(new_pos).to eq(13) # Position after "```\n"
      expect(tracker.in_fenced_block).to be false
    end

    it "rejects a closing fence followed by non-whitespace content" do
      input = "```\ncode\n``` text"
      tracker.check_fenced_boundary(input, 0, line_start: true)

      new_pos = tracker.check_fenced_boundary(input, 9, line_start: true)
      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be true
    end

    it "requires matching fence character for close" do
      input = "```\ncode\n~~~"
      # Open with backticks
      tracker.check_fenced_boundary(input, 0, line_start: true)

      # Try to close with tildes - should not work
      new_pos = tracker.check_fenced_boundary(input, 9, line_start: true)
      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be true
    end

    it "allows closing fence with more characters" do
      input = "```\ncode\n`````"
      # Open
      tracker.check_fenced_boundary(input, 0, line_start: true)

      # Close with more backticks
      new_pos = tracker.check_fenced_boundary(input, 9, line_start: true)
      expect(new_pos).to eq(14)
      expect(tracker.in_fenced_block).to be false
    end

    # Kills mutations that drop `fence_length >= @fence_length` from
    # try_close_fence's guard. A candidate closing fence with FEWER
    # chars than the opening must not close it.
    it "rejects closing fence with fewer characters than opening" do
      input = "````\ncode\n```\ncontent"
      # Open with 4 backticks
      tracker.check_fenced_boundary(input, 0, line_start: true)
      expect(tracker.in_fenced_block).to be true

      # "```" (3 backticks) should NOT close the 4-backtick fence
      new_pos = tracker.check_fenced_boundary(input, 10, line_start: true)
      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be true
    end

    # Kills mutations that drop `input[scan_pos] == "\n"` from the
    # trailing-whitespace guard. After a closing fence with non-newline
    # non-space trailing content (e.g. "```XYZ"), it must NOT close.
    it "rejects closing fence followed by non-space non-newline content" do
      input = "```\ncode\n```XYZ"
      tracker.check_fenced_boundary(input, 0, line_start: true)
      expect(tracker.in_fenced_block).to be true

      # "```XYZ" has trailing "XYZ" — not spaces-then-newline/EOF
      new_pos = tracker.check_fenced_boundary(input, 9, line_start: true)
      expect(new_pos).to be_nil
      expect(tracker.in_fenced_block).to be true
    end

    it "handles fence with language identifier" do
      input = "```ruby\ncode\n```"
      new_pos = tracker.check_fenced_boundary(input, 0, line_start: true)

      expect(new_pos).to eq(8) # After "```ruby\n"
      expect(tracker.in_fenced_block).to be true
    end
  end

  describe "#check_inline_boundary" do
    it "detects opening backtick" do
      input = "`code`"
      new_pos = tracker.check_inline_boundary(input, 0)

      expect(new_pos).to eq(1)
      expect(tracker.in_inline_code).to be true
    end

    # Kills `@inline_delimiter = input[delimiter_start...pos]` →
    # `@inline_delimiter = input[nil...pos]`. With nil-start the
    # slice starts at 0, swallowing any prefix before the delimiter.
    it "detects opening backticks at a mid-string position" do
      input = "xx``code``"
      new_pos = tracker.check_inline_boundary(input, 2)

      expect(new_pos).to eq(4)
      # `close at pos 8 only succeeds if @inline_delimiter was set
      # to exactly "``" (2 backticks starting at pos 2) — the mutation
      # would produce "xx``" (4 chars) and close wouldn't match.
      close_pos = tracker.check_inline_boundary(input, 8)
      expect(close_pos).to eq(10)
      expect(tracker.in_inline_code).to be false
    end

    # Kills mutations on the `input[pos] != "`"` guard. At a non-backtick
    # position the method must return nil without touching in_inline_code
    # or @inline_delimiter; otherwise mutations to `if nil` / `if false`
    # / `if input[pos].eql?("`")` etc. would fall through to open_inline
    # and return a non-nil position.
    it "returns nil at non-backtick positions" do
      input = "hello `code`"
      new_pos = tracker.check_inline_boundary(input, 0)

      expect(new_pos).to be_nil
      expect(tracker.in_inline_code).to be false
    end

    it "returns nil past end of input" do
      input = "abc"
      new_pos = tracker.check_inline_boundary(input, 3)

      expect(new_pos).to be_nil
      expect(tracker.in_inline_code).to be false
    end

    it "detects closing backtick" do
      input = "`code`"
      tracker.check_inline_boundary(input, 0) # Open

      new_pos = tracker.check_inline_boundary(input, 5)
      expect(new_pos).to eq(6)
      expect(tracker.in_inline_code).to be false
    end

    it "handles double backticks" do
      input = "``code with ` inside``"
      # Open with ``
      new_pos = tracker.check_inline_boundary(input, 0)
      expect(new_pos).to eq(2)
      expect(tracker.in_inline_code).to be true

      # Single ` at pos 12 (one backtick not matching the `` delimiter)
      # must NOT close the inline. Kills try_close_inline mutations
      # that drop the `input[pos, delim_length] == @inline_delimiter`
      # guard — without it, a lone `` ` `` would satisfy the
      # "no trailing backtick" check and spuriously close the span.
      new_pos = tracker.check_inline_boundary(input, 12)
      expect(new_pos).to be_nil
      expect(tracker.in_inline_code).to be true

      # Close with ``
      new_pos = tracker.check_inline_boundary(input, 20)
      expect(new_pos).to eq(22)
      expect(tracker.in_inline_code).to be false
    end

    it "does not detect inline code when in fenced block" do
      input = "```\n`code`\n```"
      tracker.check_fenced_boundary(input, 0, line_start: true)

      new_pos = tracker.check_inline_boundary(input, 4)
      expect(new_pos).to be_nil
    end

    it "does not detect inline code when in indented block" do
      input = "    `code`"
      tracker.check_indented_boundary(input, 0, line_start: true)

      new_pos = tracker.check_inline_boundary(input, 4)
      expect(new_pos).to be_nil
    end
  end

  describe "#check_indented_boundary" do
    it "detects line with 4 spaces as code" do
      input = "    code line"
      new_pos = tracker.check_indented_boundary(input, 0, line_start: true)

      expect(new_pos).to eq(13)
      expect(tracker.in_indented_block).to be true
    end

    it "detects line with tab as code" do
      input = "\tcode line"
      new_pos = tracker.check_indented_boundary(input, 0, line_start: true)

      expect(new_pos).to eq(10)
      expect(tracker.in_indented_block).to be true
    end

    it "does not detect line with 3 spaces as code" do
      input = "   not code"
      new_pos = tracker.check_indented_boundary(input, 0, line_start: true)

      expect(new_pos).to be_nil
      expect(tracker.in_indented_block).to be false
    end

    it "requires line_start to be true" do
      input = "text    code"
      new_pos = tracker.check_indented_boundary(input, 4, line_start: false)

      expect(new_pos).to be_nil
    end

    it "continues indented block for subsequent indented lines" do
      input = "    line1\n    line2"
      # First line
      tracker.check_indented_boundary(input, 0, line_start: true)
      expect(tracker.in_indented_block).to be true

      # Second line
      new_pos = tracker.check_indented_boundary(input, 10, line_start: true)
      expect(new_pos).to eq(19)
      expect(tracker.in_indented_block).to be true
    end

    it "continues indented block through blank lines" do
      input = "    line1\n\n    line2"
      # First line
      tracker.check_indented_boundary(input, 0, line_start: true)

      # Blank line
      new_pos = tracker.check_indented_boundary(input, 10, line_start: true)
      expect(new_pos).to eq(11)
      expect(tracker.in_indented_block).to be true

      # Second indented line
      new_pos = tracker.check_indented_boundary(input, 11, line_start: true)
      expect(new_pos).to eq(20)
      expect(tracker.in_indented_block).to be true
    end

    # Kills `is_blank = line_content.match?(/\A\s*\z/)` → `.match?(/\A\S*\z/)`.
    # A whitespace-only line (not empty) must still count as blank so
    # the indented block continues across it. With `\S*`, a 3-space
    # line fails the blank check AND fails the code-indent check
    # (start_with?("    ") wants 4), so the block ends.
    it "continues indented block across a whitespace-only (<4 spaces) line" do
      input = "    line1\n   \n    line2"
      # Start block
      tracker.check_indented_boundary(input, 0, line_start: true)
      expect(tracker.in_indented_block).to be true

      # Whitespace-only line (3 spaces)
      new_pos = tracker.check_indented_boundary(input, 10, line_start: true)
      expect(new_pos).not_to be_nil
      expect(tracker.in_indented_block).to be true
    end

    it "ends indented block on non-indented line" do
      input = "    code\nnot code"
      # Start code block
      tracker.check_indented_boundary(input, 0, line_start: true)
      expect(tracker.in_indented_block).to be true

      # Non-indented line
      new_pos = tracker.check_indented_boundary(input, 9, line_start: true)
      expect(new_pos).to be_nil
      expect(tracker.in_indented_block).to be false
    end

    it "does not start indented block when in fenced block" do
      input = "```\n    code\n```"
      tracker.check_fenced_boundary(input, 0, line_start: true)

      new_pos = tracker.check_indented_boundary(input, 4, line_start: true)
      expect(new_pos).to be_nil
      expect(tracker.in_indented_block).to be false
    end

    it "handles more than 4 spaces" do
      input = "        deeply indented"
      new_pos = tracker.check_indented_boundary(input, 0, line_start: true)

      expect(new_pos).to eq(23)
      expect(tracker.in_indented_block).to be true
    end
  end

  describe "#reset!" do
    it "resets all state" do
      input = "```\ncode"
      tracker.check_fenced_boundary(input, 0, line_start: true)
      expect(tracker.in_code?).to be true

      tracker.reset!

      expect(tracker.in_code?).to be false
      expect(tracker.in_fenced_block).to be false
      expect(tracker.in_indented_block).to be false
      expect(tracker.in_inline_code).to be false
    end

    it "resets indented block state" do
      input = "    code"
      tracker.check_indented_boundary(input, 0, line_start: true)
      expect(tracker.in_indented_block).to be true

      tracker.reset!

      expect(tracker.in_indented_block).to be false
    end

    it "resets inline code state" do
      input = "`code"
      tracker.check_inline_boundary(input, 0)
      expect(tracker.in_inline_code).to be true

      tracker.reset!

      expect(tracker.in_inline_code).to be false
    end
  end
end
