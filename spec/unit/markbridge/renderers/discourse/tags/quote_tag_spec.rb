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
      expect(result).to eq("> This is a quote\n\n")
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
      expect(result).to eq("> Line 1\n> Line 2\n> Line 3\n\n")
    end

    it "falls back to author-only form when post is missing but topic and username are set" do
      element = Markbridge::AST::Quote.new(author: "John", topic: "456", username: "john")
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("[quote=\"John\"]\nhi\n[/quote]\n\n")
    end

    it "falls back to author-only form when topic is missing but post and username are set" do
      element = Markbridge::AST::Quote.new(author: "John", post: "123", username: "john")
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("[quote=\"John\"]\nhi\n[/quote]\n\n")
    end

    it "falls back to author-only form when username is missing but post and topic are set" do
      element = Markbridge::AST::Quote.new(author: "John", post: "123", topic: "456")
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("[quote=\"John\"]\nhi\n[/quote]\n\n")
    end

    it "falls back to plain blockquote when no attribution is present" do
      element = Markbridge::AST::Quote.new(post: "123", topic: "456")
      element << Markbridge::AST::Text.new("hi")

      # post + topic without username AND without author -> plain blockquote
      expect(tag.render(element, interface)).to eq("> hi\n\n")
    end

    let(:element_class) { Markbridge::AST::Quote }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <blockquote>" do
        element = Markbridge::AST::Quote.new
        element << Markbridge::AST::Text.new("Hi")

        expect(tag.render(element, interface)).to eq("<blockquote>Hi</blockquote>")
      end

      it "drops BBCode attribution in html_mode" do
        element = Markbridge::AST::Quote.new(author: "John")
        element << Markbridge::AST::Text.new("Hi")

        expect(tag.render(element, interface)).to eq("<blockquote>Hi</blockquote>")
      end
    end
  end
end
