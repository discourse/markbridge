# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::PollTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "emits a trailing blank line after a reconstructed poll" do
      element = Markbridge::AST::Poll.new(name: "fav", type: "regular", options: %w[A B])

      result = tag.render(element, interface)

      expect(result).to end_with("[/poll]\n\n")
    end

    it "emits a trailing blank line after a raw-passthrough poll" do
      element = Markbridge::AST::Poll.new(raw: "[poll]\n* A\n* B\n[/poll]")

      result = tag.render(element, interface)

      expect(result).to eq("[poll]\n* A\n* B\n[/poll]\n\n")
    end
  end
end
