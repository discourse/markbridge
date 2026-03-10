# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::QuoteTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders plain quote as Markdown blockquote" do
      element = Markbridge::AST::Quote.new
      element << Markbridge::AST::Text.new("This is a quote")

      result = tag.render(element, interface)
      expect(result).to eq("> This is a quote")
    end

    it "renders quote with author as Discourse BBCode" do
      element = Markbridge::AST::Quote.new(author: "John")
      element << Markbridge::AST::Text.new("This is a quote")

      result = tag.render(element, interface)
      expect(result).to eq("[quote=\"John\"]\nThis is a quote\n[/quote]\n\n")
    end

    it "renders quote with full Discourse context" do
      element = Markbridge::AST::Quote.new(username: "john", post: "123", topic: "456")
      element << Markbridge::AST::Text.new("This is a quote")

      result = tag.render(element, interface)
      expect(result).to eq("[quote=\"john, post:123, topic:456\"]\nThis is a quote\n[/quote]\n\n")
    end

    it "renders multi-line plain quote with blockquote syntax" do
      element = Markbridge::AST::Quote.new
      element << Markbridge::AST::Text.new("Line 1\nLine 2\nLine 3")

      result = tag.render(element, interface)
      expect(result).to eq("> Line 1\n> Line 2\n> Line 3")
    end
  end
end
