# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tag do
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:element) { Markbridge::AST::Bold.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "calls the block when provided" do
      tag = described_class.new { |elem, _interface| "rendered: #{elem.class}" }

      result = tag.render(element, interface)
      expect(result).to eq("rendered: Markbridge::AST::Bold")
    end

    it "raises NotImplementedError when no block provided" do
      tag = described_class.new

      expect { tag.render(element, interface) }.to raise_error(NotImplementedError)
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
