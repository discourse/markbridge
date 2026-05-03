# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::LineBreakTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "returns a single newline" do
      expect(tag.render(Markbridge::AST::LineBreak.new, interface)).to eq("\n")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <br>" do
        expect(tag.render(Markbridge::AST::LineBreak.new, interface)).to eq("<br>")
      end
    end
  end

  describe "#html_mode_aware?" do
    it "returns true" do
      expect(described_class.new.html_mode_aware?).to be true
    end
  end
end
