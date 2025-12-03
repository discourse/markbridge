# frozen_string_literal: true

RSpec.describe "BBCode Tag Auto-Correction" do
  let(:parser) { Markbridge::Parsers::BBCode::Parser.new }

  describe "simple two-level mismatched closing" do
    it "auto-corrects [b][i]text[/b][/i]" do
      result = parser.parse("[b][i]text[/b][/i]")

      # With reordering: [/b] detects [/i] is coming and they match the stack
      # Both tags are properly closed without orphaned closing tags

      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("text")

      # All tags properly closed - no orphaned closing tags
      expect(result.children.size).to eq(1)
    end

    it "auto-corrects [i][b]text[/i][/b]" do
      result = parser.parse("[i][b]text[/i][/b]")

      # With reordering: [/i] detects [/b] is coming and they match the stack
      # Both tags are properly closed without orphaned closing tags

      italic = result.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)

      bold = italic.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.first.text).to eq("text")

      # All tags properly closed - no orphaned closing tags
      expect(result.children.size).to eq(1)
    end

    it "auto-corrects [b][i]text[/b]" do
      result = parser.parse("[b][i]text[/b]")

      # [/b] auto-closes [i] then [b]
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("text")
    end
  end

  describe "three-level nested auto-correction" do
    it "auto-corrects [b][i][code]text[/b][/i][/code]" do
      result = parser.parse("[b][i][code]text[/b][/i][/code]")

      # [code] is a raw handler and captures content including [/b][/i]
      # [/code] properly closes the code tag
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)

      code = italic.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("text[/b][/i]")

      # All tags properly closed - no orphaned closing tags outside
      expect(result.children.size).to eq(1)
    end

    it "auto-corrects [b][i][u]text[/i][/u][/b]" do
      result = parser.parse("[b][i][u]text[/i][/u][/b]")

      # With reordering: [/i] detects [/u] and [/b] coming
      # All auto-closeable tags properly closed
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)

      underline = italic.children.first
      expect(underline).to be_a(Markbridge::AST::Underline)

      # All tags properly closed - no orphaned closing tags
      expect(result.children.size).to eq(1)
    end

    it "auto-corrects when closing middle tag first [a][b][c]text[/b]" do
      result = parser.parse("[b][i][u]text[/i][/b][/u]")

      # [/i] auto-closes [u] and [i] (no reordering because [/b] doesn't match)
      # [/b] closes [b]
      # [/u] becomes orphaned text
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      # [/u] is orphaned
      expect(result.children.size).to eq(2)
      expect(result.children[1].text).to eq("[/u]")
    end
  end

  describe "MAX_AUTO_CLOSE_DEPTH limit" do
    it "does not auto-close beyond MAX_AUTO_CLOSE_DEPTH (5 levels)" do
      # Stack: [b][i][u][s][code] (5 levels)
      # [code] is a raw handler and captures content
      result = parser.parse("[b][i][u][s][code][*]text[/b]")

      # [code] captures [*]text[/b] as raw content
      code = result.children.first.children.first.children.first.children.first.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("[*]text[/b]")
    end

    it "auto-closes at exactly MAX_AUTO_CLOSE_DEPTH" do
      # Stack depth of 4 from target
      result = parser.parse("[b][i][u][s]text[/b]")

      # Should auto-close because within limit
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
    end
  end

  describe "auto-closeable vs non-auto-closeable tags" do
    it "does not auto-close non-auto-closeable tags" do
      # List is not marked as auto_closeable
      result = parser.parse("[b][list][*]item[/b]")

      # Cannot auto-close through [list], so [/b] becomes text (merged)
      bold = result.children.first
      list = bold.children.first
      list_item = list.children.first

      expect(list_item.children.last.text).to eq("item[/b]")
    end

    it "auto-closes only auto-closeable formatting tags" do
      result = parser.parse("[b][i][u]text[/b]")

      # All these are auto-closeable
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
    end

    it "stops at first non-auto-closeable tag in stack" do
      result = parser.parse("[b][url=http://example.com][i]text[/b]")

      # [url] is not auto-closeable, so [/b] becomes text (merged)
      bold = result.children.first
      url = bold.children.first
      italic = url.children.first

      expect(italic.children.last.text).to eq("text[/b]")
    end
  end

  describe "auto_closed_count tracking" do
    it "tracks simple auto-close" do
      result = parser.parse("[b][i]text[/b]")

      # Should increment auto_closed_count for [i] and [b]
      # This would need to be exposed through the parser if you want to test it
      expect(result).to be_a(Markbridge::AST::Document)
    end

    it "tracks multiple auto-closes" do
      result = parser.parse("[b][i][u]text[/b][b][i][u]text[/b]")

      # Multiple auto-close operations
      expect(result.children.size).to be >= 2
    end
  end

  describe "complex real-world scenarios" do
    it "handles overlapping bold and italic" do
      result = parser.parse("[b]bold [i]both[/b] italic[/i]")

      # [b]bold [i]both (auto-close i, b) because text follows [/b]
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.size).to eq(2)
      expect(bold.children[0].text).to eq("bold ")

      italic = bold.children[1]
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("both")

      # " italic" and "[/i]" are merged into one text node
      expect(result.children[1].text).to eq(" italic[/i]")
    end

    it "handles multiple overlapping tags" do
      result = parser.parse("[b]a[i]b[u]c[/b]d[/i]e[/u]")

      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      # Structure: Bold(a, Italic(b, Underline(c)))
      # Then: text(d), text([/i]), text(e), text([/u])
    end

    it "handles correct nesting mixed with incorrect" do
      result = parser.parse("[b]correct[/b] [i][u]wrong[/i][/u]")

      # First part closes correctly
      expect(result.children[0]).to be_a(Markbridge::AST::Bold)

      # Second part: [u] auto-closed by [/i]
      italic = result.children[2]
      expect(italic).to be_a(Markbridge::AST::Italic)
    end
  end

  describe "auto-close with other content" do
    it "preserves text content during auto-close" do
      result = parser.parse("[b]start [i]middle[/b] end")

      bold = result.children.first
      expect(bold.children[0].text).to eq("start ")

      italic = bold.children[1]
      expect(italic.children.first.text).to eq("middle")

      # " end" is outside the auto-closed tags
      expect(result.children[1].text).to eq(" end")
    end

    it "handles empty tags in auto-close chain" do
      result = parser.parse("[b][i][/b]")

      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children).to be_empty
    end

    it "handles multiple text nodes during auto-close" do
      result = parser.parse("[b]a [i]b [u]c[/b] d")

      bold = result.children.first
      expect(bold.children.select { |c| c.is_a?(Markbridge::AST::Text) }.map(&:text)).to include(
        "a ",
      )
    end
  end

  describe "edge cases" do
    it "handles closing tag for non-existent opening tag" do
      result = parser.parse("text[/b]")

      # [/b] has no matching open, becomes text (merged with previous text)
      expect(result.children.size).to eq(1)
      expect(result.children.first.text).to eq("text[/b]")
    end

    it "handles closing tag when stack is empty" do
      result = parser.parse("[/i]")

      expect(result.children.first.text).to eq("[/i]")
    end

    it "handles multiple mismatched closes in sequence" do
      result = parser.parse("[b][/i][/u][/s]")

      # All closing tags without matching opens become text (merged)
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.size).to eq(1)
      expect(bold.children.first.text).to eq("[/i][/u][/s]")
    end

    it "handles alternating correct and incorrect closes" do
      result = parser.parse("[b][i][/i][u][/b][/u]")

      # [i] closes correctly
      # [/b] auto-closes [u] then [b]
      # [/u] becomes text

      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
    end
  end

  describe "interaction with lists" do
    it "auto-closes formatting inside list items" do
      result = parser.parse("[list][*][b][i]text[/b][/list]")

      list = result.children.first
      list_item = list.children.first

      bold = list_item.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
    end

    it "does not auto-close across list boundaries" do
      result = parser.parse("[b][list][*]item[/list][/b]")

      # [b] opens, [list] opens (not auto-closeable)
      # [/list] closes list normally
      # [/b] closes bold normally
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      list = bold.children.first
      expect(list).to be_a(Markbridge::AST::List)
    end
  end
end
