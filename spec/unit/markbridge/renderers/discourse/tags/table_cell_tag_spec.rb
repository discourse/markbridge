# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::TableCellTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    # TableCellTag is a passthrough safety net — the real table rendering
    # happens in TableTag. But the render method must still return its
    # children's output (without raising), so mutations that reduce
    # the body to `super` or `raise` are distinguishable.
    it "renders children's text without raising" do
      cell = Markbridge::AST::TableCell.new
      cell << Markbridge::AST::Text.new("cell text")

      result = tag.render(cell, interface)

      expect(result).to include("cell text")
    end

    it "returns an empty string for an empty cell" do
      cell = Markbridge::AST::TableCell.new

      expect(tag.render(cell, interface)).to eq("")
    end
  end

  describe "#html_mode_aware?" do
    it "returns true" do
      expect(described_class.new.html_mode_aware?).to be true
    end
  end
end
