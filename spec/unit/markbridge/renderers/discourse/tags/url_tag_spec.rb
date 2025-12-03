# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UrlTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders URL with valid href" do
      element = Markbridge::AST::Url.new(href: "https://example.com")
      element << Markbridge::AST::Text.new("Example")

      result = tag.render(element, interface)
      expect(result).to eq("[Example](https://example.com)")
    end

    it "renders http URLs" do
      element = Markbridge::AST::Url.new(href: "http://example.com")
      element << Markbridge::AST::Text.new("Example")

      result = tag.render(element, interface)
      expect(result).to eq("[Example](http://example.com)")
    end

    it "renders https URLs" do
      element = Markbridge::AST::Url.new(href: "https://secure.com")
      element << Markbridge::AST::Text.new("Secure")

      result = tag.render(element, interface)
      expect(result).to eq("[Secure](https://secure.com)")
    end

    it "renders mailto URLs" do
      element = Markbridge::AST::Url.new(href: "mailto:test@example.com")
      element << Markbridge::AST::Text.new("Email")

      result = tag.render(element, interface)
      expect(result).to eq("[Email](mailto:test@example.com)")
    end

    it "returns text only for invalid href" do
      element = Markbridge::AST::Url.new(href: "javascript:alert(1)")
      element << Markbridge::AST::Text.new("Bad Link")

      result = tag.render(element, interface)
      expect(result).to eq("Bad Link")
    end

    it "returns text only when href is nil" do
      element = Markbridge::AST::Url.new
      element << Markbridge::AST::Text.new("No Link")

      result = tag.render(element, interface)
      expect(result).to eq("No Link")
    end
  end
end
