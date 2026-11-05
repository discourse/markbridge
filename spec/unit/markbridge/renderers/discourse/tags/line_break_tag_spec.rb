# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::LineBreakTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "returns the hard break token" do
      expect(tag.render(Markbridge::AST::LineBreak.new, interface)).to eq(
        [Markbridge::Renderers::Discourse::Inline::Tokens.hard_break],
      )
    end

    it "renders as <br> after a line that holds only whitespace" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("a") << Markbridge::AST::LineBreak.new <<
        Markbridge::AST::Text.new(" \t")
      document << Markbridge::AST::LineBreak.new << Markbridge::AST::Text.new("b")

      expect(renderer.render(document)).to eq("a\n \t<br>b")
    end

    it "keeps a text that starts with a newline on the line after it" do
      item =
        Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("x") <<
          Markbridge::AST::LineBreak.new
      item << Markbridge::AST::Text.new("\ny")
      document = Markbridge::AST::Document.new << (Markbridge::AST::List.new << item)

      expect(renderer.render(document)).to eq("\n\n- x\n  <br>y\n\n\n")
    end

    it "renders as nothing after a blank line" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("a\n\n") << Markbridge::AST::LineBreak.new <<
        Markbridge::AST::Text.new("b")

      expect(renderer.render(document)).to eq("a\n\nb")
    end

    it "renders as <br> at the start of an emphasis that starts a line" do
      first =
        Markbridge::AST::Bold.new << Markbridge::AST::Text.new("a") <<
          Markbridge::AST::LineBreak.new
      second =
        Markbridge::AST::Bold.new << Markbridge::AST::LineBreak.new <<
          Markbridge::AST::Text.new("b")
      document = Markbridge::AST::Document.new << first << second

      expect(renderer.render(document)).to eq("**a**\n**<br>b**")
    end

    it "renders as a newline, and as <br> after another break" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("a") << Markbridge::AST::LineBreak.new <<
        Markbridge::AST::LineBreak.new
      document << Markbridge::AST::Text.new("b")

      expect(renderer.render(document)).to eq("a\n<br>b")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

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
