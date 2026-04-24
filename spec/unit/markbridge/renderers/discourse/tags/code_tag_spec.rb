# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::CodeTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders inline code without language" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("code")

      result = tag.render(element, interface)
      expect(result).to eq("`code`")
    end

    it "renders block code with newlines" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("line1\nline2")

      result = tag.render(element, interface)
      expect(result).to include("```")
      expect(result).to include("line1\nline2")
    end

    it "includes language in block code" do
      element = Markbridge::AST::Code.new(language: "ruby")
      element << Markbridge::AST::Text.new("puts 'hello'\nputs 'world'")

      result = tag.render(element, interface)
      expect(result).to include("```ruby")
    end

    it "uses ``` fence when code contains single backticks" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("code with `backticks`\nmore")

      result = tag.render(element, interface)
      # Single backticks only need 3-backtick fence (smarter than always using tildes)
      expect(result).to start_with("```\n")
      expect(result).to end_with("\n```\n\n")
    end

    it "uses tildes when code contains triple backticks (more efficient)" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("```\ncode block\nwith fences\n```")

      result = tag.render(element, interface)
      # Tildes (3) are more efficient than backticks (4)
      expect(result).to start_with("~~~\n")
      expect(result).to end_with("\n~~~\n\n")
    end

    it "uses tildes when code contains long backtick sequences" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("`````\ncode block\n`````")

      result = tag.render(element, interface)
      # Tildes (3) are more efficient than backticks (6)
      expect(result).to start_with("~~~\n")
      expect(result).to end_with("\n~~~\n\n")
    end

    it "uses backticks when content has long tilde sequences" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("~~~\ncode with tildes\n~~~")

      result = tag.render(element, interface)
      # Backticks (3) are more efficient than tildes (4)
      expect(result).to start_with("```\n")
      expect(result).to end_with("\n```\n\n")
    end

    it "handles content with both backticks and tildes" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("```\nand\n~~~")

      result = tag.render(element, interface)
      # Should use ~~~~ (4 tildes) since it's shorter than ```` (4 backticks)
      # Actually both are equal, so backticks win
      expect(result).to start_with("````\n")
      expect(result).to end_with("\n````\n\n")
    end
  end
end
