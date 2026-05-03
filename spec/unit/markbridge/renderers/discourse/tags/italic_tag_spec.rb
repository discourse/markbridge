# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ItalicTag do
  let(:element_class) { Markbridge::AST::Italic }
  let(:empty_output) { "" }
  let(:simple_output) { "*hi*" }

  it_behaves_like "an inline wrapping tag"

  describe "#render in html_mode" do
    let(:tag) { described_class.new }
    let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
    let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }
    let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

    it "wraps content in <em>" do
      element = Markbridge::AST::Italic.new
      element << Markbridge::AST::Text.new("hello")

      expect(tag.render(element, interface)).to eq("<em>hello</em>")
    end
  end
end
