# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ColorTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "wraps content in a styled span when color is set" do
      element = Markbridge::AST::Color.new(color: "red")
      element << Markbridge::AST::Text.new("hi")

      expect(rendered(element)).to eq('<span style="color: red">hi</span>')
    end

    it "passes the color value through verbatim" do
      element = Markbridge::AST::Color.new(color: "#ff0000")
      element << Markbridge::AST::Text.new("hi")

      expect(rendered(element)).to eq('<span style="color: #ff0000">hi</span>')
    end

    it "writes a line break at the start as <br>, so the tag is not alone on its line" do
      element = Markbridge::AST::Color.new(color: "red")
      element << Markbridge::AST::LineBreak.new << Markbridge::AST::Text.new("hi")

      expect(rendered(element)).to eq('<span style="color: red"><br>hi</span>')
    end

    it "returns just the content when no color is set" do
      element = Markbridge::AST::Color.new
      element << Markbridge::AST::Text.new("hi")

      expect(rendered(element)).to eq("hi")
    end

    let(:element_class) { Markbridge::AST::Color }
    it_behaves_like "a tag that propagates parent context"
  end
end
