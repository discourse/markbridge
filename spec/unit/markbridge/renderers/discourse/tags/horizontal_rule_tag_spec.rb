# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::HorizontalRuleTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "returns a horizontal rule surrounded by blank lines" do
      expect(tag.render(Markbridge::AST::HorizontalRule.new, interface)).to eq("\n\n---\n\n")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <hr>" do
        expect(tag.render(Markbridge::AST::HorizontalRule.new, interface)).to eq("<hr>")
      end
    end
  end

  describe "#html_mode_aware?" do
    it "returns true" do
      expect(described_class.new.html_mode_aware?).to be true
    end
  end
end
