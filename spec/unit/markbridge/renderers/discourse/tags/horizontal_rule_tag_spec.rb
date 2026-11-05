# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::HorizontalRuleTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "returns a horizontal rule surrounded by blank lines" do
      expect(tag.render(Markbridge::AST::HorizontalRule.new, interface)).to eq("\n\n---\n\n")
    end

    it "uses stars inside a list item, so the rule does not end the list" do
      item = Markbridge::AST::ListItem.new
      context =
        Markbridge::Renderers::Discourse::RenderContext.new([Markbridge::AST::List.new, item])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      expect(tag.render(Markbridge::AST::HorizontalRule.new, interface)).to eq("\n\n* * *\n\n")
    end

    context "in html_mode" do
      let(:context) { html_context }

      it "renders <hr>" do
        expect(tag.render(Markbridge::AST::HorizontalRule.new, interface)).to eq("<hr>")
      end
    end
  end
end
