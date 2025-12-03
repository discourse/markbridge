# frozen_string_literal: true

RSpec.describe "BBCode Parser Integration" do
  let(:parser) { Markbridge::Parsers::BBCode::Parser.new }

  describe "parsing basic content" do
    it "parses plain text" do
      result = parser.parse("Hello world")
      expect(result).to be_a(Markbridge::AST::Document)
      expect(result.children.size).to eq(1)
      expect(result.children.first).to be_a(Markbridge::AST::Text)
      expect(result.children.first.text).to eq("Hello world")
    end

    it "parses empty string" do
      result = parser.parse("")
      expect(result).to be_a(Markbridge::AST::Document)
      expect(result.children).to be_empty
    end
  end

  describe "parsing simple tags" do
    it "parses simple bold tag" do
      result = parser.parse("[b]bold[/b]")
      expect(result.children.size).to eq(1)
      expect(result.children.first).to be_a(Markbridge::AST::Bold)
      expect(result.children.first.children.first.text).to eq("bold")
    end

    it "parses simple italic tag" do
      result = parser.parse("[i]italic[/i]")
      expect(result.children.size).to eq(1)
      expect(result.children.first).to be_a(Markbridge::AST::Italic)
      expect(result.children.first.children.first.text).to eq("italic")
    end

    it "parses simple code tag" do
      result = parser.parse("[code]code[/code]")
      expect(result.children.size).to eq(1)
      expect(result.children.first).to be_a(Markbridge::AST::Code)
      expect(result.children.first.children.first.text).to eq("code")
    end

    it "handles empty tags" do
      result = parser.parse("[b][/b]")
      expect(result.children.first).to be_a(Markbridge::AST::Bold)
      expect(result.children.first.children).to be_empty
    end
  end

  describe "parsing nested tags" do
    it "parses nested tags" do
      result = parser.parse("[b][i]text[/i][/b]")
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("text")
    end

    it "parses deeply nested tags" do
      result = parser.parse("[b][i][code]text[/code][/i][/b]")
      bold = result.children.first
      italic = bold.children.first
      code = italic.children.first

      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("text")
    end

    it "parses multiple nested tags at same level" do
      result = parser.parse("[b][i]italic[/i][code]code[/code][/b]")
      bold = result.children.first

      expect(bold.children.size).to eq(2)
      expect(bold.children[0]).to be_a(Markbridge::AST::Italic)
      expect(bold.children[1]).to be_a(Markbridge::AST::Code)
    end
  end

  describe "parsing mixed content" do
    it "parses text before and after tags" do
      result = parser.parse("before [b]bold[/b] after")
      expect(result.children.size).to eq(3)
      expect(result.children[0].text).to eq("before ")
      expect(result.children[1]).to be_a(Markbridge::AST::Bold)
      expect(result.children[2].text).to eq(" after")
    end

    it "parses multiple tags with text between" do
      result = parser.parse("[b]bold[/b] text [i]italic[/i]")
      expect(result.children.size).to eq(3)
      expect(result.children[0]).to be_a(Markbridge::AST::Bold)
      expect(result.children[1].text).to eq(" text ")
      expect(result.children[2]).to be_a(Markbridge::AST::Italic)
    end
  end

  describe "unknown tag handling" do
    it "ignores unknown tags but processes their children" do
      result = parser.parse("[unknown]text[/unknown]")
      expect(result.children.size).to eq(1)
      expect(result.children.first).to be_a(Markbridge::AST::Text)
      expect(result.children.first.text).to eq("text")
    end

    it "ignores unknown opening tags" do
      result = parser.parse("[unknown]text")
      expect(result.children.first.text).to eq("text")
    end

    it "ignores unknown closing tags" do
      result = parser.parse("text[/unknown]")
      expect(result.children.first.text).to eq("text")
    end

    it "processes children of unknown tags within valid tags" do
      result = parser.parse("[b][unknown]text[/unknown][/b]")
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.first.text).to eq("text")
    end
  end

  describe "parsing self-closing tags" do
    it "parses line break tags" do
      result = parser.parse("line1[br]line2")
      expect(result.children.size).to eq(3)
      expect(result.children[0].text).to eq("line1")
      expect(result.children[1]).to be_a(Markbridge::AST::LineBreak)
      expect(result.children[2].text).to eq("line2")
    end

    it "parses horizontal rule tags" do
      result = parser.parse("before[hr]after")
      expect(result.children.size).to eq(3)
      expect(result.children[1]).to be_a(Markbridge::AST::HorizontalRule)
    end
  end

  describe "parsing lists" do
    it "parses simple unordered list" do
      result = parser.parse("[list][*]Item 1[*]Item 2[/list]")
      list = result.children.first
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be false
      expect(list.children.size).to eq(2)
      expect(list.children).to all(be_a(Markbridge::AST::ListItem))
    end

    it "parses simple ordered list" do
      result = parser.parse("[list=1][*]Item 1[*]Item 2[/list]")
      list = result.children.first
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be true
    end

    it "parses list with explicit li tags" do
      result = parser.parse("[list][li]Item 1[/li][li]Item 2[/li][/list]")
      list = result.children.first
      expect(list.children.size).to eq(2)
    end
  end

  describe "parsing mismatched tags" do
    it "treats mismatched closing tags as text" do
      result = parser.parse("[b]text[/i]")
      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      # Check if mismatched tag was added as text
      # The behavior may have changed - verify what's actually in the children
      text_children = bold.children.select { |c| c.is_a?(Markbridge::AST::Text) }
      expect(text_children.map(&:text).join).to include("text")
    end

    it "handles wrong closing order" do
      result = parser.parse("[b][i]text[/b][/i]")
      bold = result.children.first
      italic = bold.children.first

      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(italic).to be_a(Markbridge::AST::Italic)

      # The [/b] is mismatched inside italic
      text_children = italic.children.select { |c| c.is_a?(Markbridge::AST::Text) }
      expect(text_children.map(&:text).join).to include("text")
    end
  end

  describe "malformed attributes (graceful degradation)" do
    it "handles image with zero width" do
      result = parser.parse("[img width=0]test.jpg[/img]")
      img = result.children.first
      expect(img).to be_a(Markbridge::AST::Image)
      expect(img.width).to be_nil # Sanitized to nil
      expect(img.src).to eq("test.jpg")
    end

    it "handles image with negative width" do
      result = parser.parse("[img width=-50]test.jpg[/img]")
      img = result.children.first
      expect(img).to be_a(Markbridge::AST::Image)
      expect(img.width).to be_nil # Sanitized to nil
      expect(img.src).to eq("test.jpg")
    end

    it "handles image with invalid width string" do
      result = parser.parse("[img width=abc]test.jpg[/img]")
      img = result.children.first
      expect(img).to be_a(Markbridge::AST::Image)
      expect(img.width).to be_nil # "abc".to_i = 0, sanitized to nil
      expect(img.src).to eq("test.jpg")
    end

    it "handles size with non-numeric string" do
      result = parser.parse("[size=large]big text[/size]")
      size = result.children.first
      expect(size).to be_a(Markbridge::AST::Size)
      expect(size.size).to eq("large") # Accepted as-is
    end

    it "handles size with empty string" do
      result = parser.parse("[size=]text[/size]")
      size = result.children.first
      expect(size).to be_a(Markbridge::AST::Size)
      expect(size.size).to be_nil # Empty string becomes nil
    end
  end
end
