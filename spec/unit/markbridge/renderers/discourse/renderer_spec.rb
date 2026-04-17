# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Renderer do
  let(:renderer) { described_class.new }

  describe "#render" do
    it "renders a document by rendering its children" do
      document = Markbridge::AST::Document.new
      text = Markbridge::AST::Text.new("hello")
      document << text

      result = renderer.render(document)
      expect(result).to eq("hello")
    end

    it "renders text nodes" do
      text = Markbridge::AST::Text.new("hello world")
      result = renderer.render(text)
      expect(result).to eq("hello world")
    end

    it "renders elements using tag library" do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("bold text")

      result = renderer.render(bold)
      expect(result).to eq("**bold text**")
    end

    it "returns empty string for unknown node types" do
      unknown = Object.new
      result = renderer.render(unknown)
      expect(result).to eq("")
    end
  end

  describe "#render_children" do
    it "renders all children" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("hello ")
      document << Markbridge::AST::Text.new("world")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)
      expect(result).to eq("hello world")
    end

    it "handles empty children" do
      document = Markbridge::AST::Document.new
      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)
      expect(result).to eq("")
    end

    it "inserts a comment boundary when sibling emphasis delimiters would merge" do
      # Two adjacent Bold siblings would render as **x****y** (four stars),
      # which CommonMark parses ambiguously. The renderer inserts an HTML
      # comment to force the delimiter runs to stay separate.
      document = Markbridge::AST::Document.new
      first = Markbridge::AST::Bold.new
      first << Markbridge::AST::Text.new("x")
      second = Markbridge::AST::Bold.new
      second << Markbridge::AST::Text.new("y")
      document << first
      document << second

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)

      expect(result).to eq("**x**<!---->**y**")
    end

    it "does not insert a boundary when delimiters differ" do
      document = Markbridge::AST::Document.new
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("x")
      strike = Markbridge::AST::Strikethrough.new
      strike << Markbridge::AST::Text.new("y")
      document << bold
      document << strike

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)

      expect(result).to eq("**x**~~y~~")
    end
  end

  describe "RenderingInterface helpers" do
    let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
    let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

    it "returns true when content has newlines" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("line1\nline2")

      expect(interface.block_context?(code)).to be true
    end

    it "returns false when content has no newlines" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("single line")

      expect(interface.block_context?(code)).to be false
    end

    it "returns true for List elements" do
      list = Markbridge::AST::List.new(ordered: false)
      expect(interface.block_context?(list)).to be true
    end

    it "returns true for HorizontalRule elements" do
      hr = Markbridge::AST::HorizontalRule.new
      expect(interface.block_context?(hr)).to be true
    end

    it "wraps content with markers" do
      result = interface.wrap_inline("text", "**")
      expect(result).to eq("**text**")
    end

    it "uses different close marker if provided" do
      result = interface.wrap_inline("text", "[", "]")
      expect(result).to eq("[text]")
    end

    it "returns content as-is when empty after stripping" do
      result = interface.wrap_inline("   ", "**")
      expect(result).to eq("   ")
    end

    it "preserves leading whitespace" do
      result = interface.wrap_inline("  text", "**")
      expect(result).to eq("  **text**")
    end

    it "preserves trailing whitespace" do
      result = interface.wrap_inline("text  ", "**")
      expect(result).to eq("**text**  ")
    end

    it "uses HTML fallback when content contains markers" do
      result = interface.wrap_inline("text**more", "**")
      expect(result).to eq("<strong>text**more</strong>")
    end

    it "uses HTML fallback for italic conflicts" do
      result = interface.wrap_inline("text*more", "*")
      expect(result).to eq("<em>text*more</em>")
    end

    it "uses HTML fallback for strikethrough conflicts" do
      result = interface.wrap_inline("text~~more", "~~")
      expect(result).to eq("<s>text~~more</s>")
    end
  end
end
