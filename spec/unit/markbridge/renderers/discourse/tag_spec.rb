# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tag do
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:element) { Markbridge::AST::Bold.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "PASSTHROUGH" do
    it "is frozen" do
      expect(described_class::PASSTHROUGH).to be_frozen
    end

    it "renders only the element's children" do
      element << Markbridge::AST::Text.new("inside")

      expect(described_class::PASSTHROUGH.render(element, interface)).to eq("inside")
    end

    it "renders the children with the element as their parent" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("a*b")

      # With Code on the parent chain the text is not Markdown-escaped.
      expect(described_class::PASSTHROUGH.render(code, interface)).to eq("a*b")
    end
  end

  describe "#render" do
    it "calls the block when provided" do
      tag = described_class.new { |elem, _interface| "rendered: #{elem.class}" }

      result = tag.render(element, interface)
      expect(result).to eq("rendered: Markbridge::AST::Bold")
    end

    it "raises NotImplementedError naming the subclass when no block provided" do
      subclass = Class.new(described_class)
      tag = subclass.new

      expect { tag.render(element, interface) }.to raise_error(
        NotImplementedError,
        "#{subclass} must implement #render or provide a block",
      )
    end

    it "passes element and interface to block" do
      received_element = nil
      received_interface = nil

      tag =
        described_class.new do |elem, iface|
          received_element = elem
          received_interface = iface
          ""
        end

      tag.render(element, interface)

      expect(received_element).to eq(element)
      expect(received_interface).to eq(interface)
    end
  end
end
