# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::EmailTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders a markdown mailto link when an address is set" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("Contact us")

      expect(tag.render(element, interface)).to eq("[Contact us](mailto:[email protected])")
    end

    it "uses the address verbatim, not html-escaped" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("link")

      expect(tag.render(element, interface)).to eq("[link](mailto:[email protected])")
    end

    it "returns just the content when no address is set" do
      element = Markbridge::AST::Email.new
      element << Markbridge::AST::Text.new("text")

      expect(tag.render(element, interface)).to eq("text")
    end

    it "escapes ] in the label so it does not terminate the link early" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("[ABC-123] contact")

      result = tag.render(element, interface)
      expect(result).to eq("[\\[ABC-123\\] contact](mailto:[email protected])")
    end

    it "escapes every ] in the label" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("[A] and [B]")

      result = tag.render(element, interface)
      expect(result).to eq("[\\[A\\] and \\[B\\]](mailto:[email protected])")
    end

    let(:element_class) { Markbridge::AST::Email }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <a href=mailto:...> when address is set" do
        element = Markbridge::AST::Email.new(address: "user@example.com")
        element << Markbridge::AST::Text.new("Email me")

        expect(tag.render(element, interface)).to eq(
          %(<a href="mailto:user@example.com">Email me</a>),
        )
      end

      it "attribute-escapes the address" do
        element = Markbridge::AST::Email.new(address: %(weird"@example.com))
        element << Markbridge::AST::Text.new("X")

        expect(tag.render(element, interface)).to eq(
          %(<a href="mailto:weird&quot;@example.com">X</a>),
        )
      end
    end
  end
end
