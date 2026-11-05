# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::EmailTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "renders a markdown mailto link when an address is set" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("Contact us")

      expect(rendered(element)).to eq("[Contact us](<mailto:[email protected]>)")
    end

    it "writes the address as a link destination, not html-escaped" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("link")

      expect(rendered(element)).to eq("[link](<mailto:[email protected]>)")
    end

    it "returns just the content when no address is set" do
      element = Markbridge::AST::Email.new
      element << Markbridge::AST::Text.new("text")

      expect(rendered(element)).to eq("text")
    end

    it "escapes ] in the label so it does not terminate the link early" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("[ABC-123] contact")

      result = rendered(element)
      expect(result).to eq("[\\[ABC-123\\] contact](<mailto:[email protected]>)")
    end

    it "writes the address as a bare URL when the label has nothing visible" do
      element = Markbridge::AST::Email.new(address: "a@example.com")
      element << Markbridge::AST::Text.new(" ")

      expect(rendered(element)).to eq("mailto:a@example.com")

      # A bare URL, so text glued to it makes it a link like any other.
      document = Markbridge::AST::Document.new([Markbridge::AST::Text.new("see"), element])
      expect(renderer.render(document)).to eq("see[mailto:a@example.com](mailto:a@example.com)")
    end

    it "escapes every ] in the label" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("[A] and [B]")

      result = rendered(element)
      expect(result).to eq("[\\[A\\] and \\[B\\]](<mailto:[email protected]>)")
    end

    let(:element_class) { Markbridge::AST::Email }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { html_context }

      it "renders <a href=mailto:...> when address is set" do
        element = Markbridge::AST::Email.new(address: "user@example.com")
        element << Markbridge::AST::Text.new("Email me")

        expect(rendered(element)).to eq(%(<a href="mailto:user@example.com">Email me</a>))
      end

      it "attribute-escapes the address" do
        element = Markbridge::AST::Email.new(address: %(weird"@example.com))
        element << Markbridge::AST::Text.new("X")

        expect(rendered(element)).to eq(%(<a href="mailto:weird&quot;@example.com">X</a>))
      end
    end
  end
end
