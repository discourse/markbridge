# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::LineBreakTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "returns the hard break token" do
      expect(tag.render(Markbridge::AST::LineBreak.new, interface)).to eq(
        [Markbridge::Renderers::Discourse::Inline::Tokens.hard_break],
      )
    end

    it "renders as a newline, and as <br> after another break" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("a") << Markbridge::AST::LineBreak.new <<
        Markbridge::AST::LineBreak.new
      document << Markbridge::AST::Text.new("b")

      expect(renderer.render(document)).to eq("a\n<br>b")
    end

    context "in html_mode" do
      let(:context) { html_context }

      it "renders <br>" do
        expect(
          renderer.serialize(tag.render(Markbridge::AST::LineBreak.new, interface), context),
        ).to eq("<br>")
      end
    end

    context "in a heading" do
      let(:context) do
        Markbridge::Renderers::Discourse::RenderContext.new(
          [Markbridge::AST::Heading.new(level: 1)],
        )
      end

      it "renders <br>, a heading is one line" do
        expect(tag.render(Markbridge::AST::LineBreak.new, interface)).to eq("<br>")
      end
    end
  end
end
