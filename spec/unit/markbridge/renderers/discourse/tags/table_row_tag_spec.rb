# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::TableRowTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    # TableRowTag is a passthrough safety net — the real table rendering
    # happens in TableTag. But the render method must still return its
    # children's output (without raising), so mutations that reduce
    # the body to `super` or `raise` are distinguishable.
    it "renders children's text without raising" do
      row = Markbridge::AST::TableRow.new
      cell = Markbridge::AST::TableCell.new
      cell << Markbridge::AST::Text.new("cell content")
      row << cell

      result = tag.render(row, interface)

      expect(result).to include("cell content")
    end

    it "returns an empty string for an empty row" do
      row = Markbridge::AST::TableRow.new

      expect(tag.render(row, interface)).to eq("")
    end
  end
end
