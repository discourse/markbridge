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

    it "uses ~~~ fence when code contains backticks" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("code with `backticks`\nmore")

      result = tag.render(element, interface)
      expect(result).to include("~~~")
    end
  end
end
