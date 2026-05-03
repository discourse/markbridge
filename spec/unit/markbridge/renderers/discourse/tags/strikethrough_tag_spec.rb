# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::StrikethroughTag do
  let(:element_class) { Markbridge::AST::Strikethrough }
  let(:empty_output) { "" }
  let(:simple_output) { "~~hi~~" }

  it_behaves_like "an inline wrapping tag"

  describe "#render in html_mode" do
    let(:tag) { described_class.new }
    let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
    let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }
    let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

    it "wraps content in <s>" do
      element = Markbridge::AST::Strikethrough.new
      element << Markbridge::AST::Text.new("hello")

      expect(tag.render(element, interface)).to eq("<s>hello</s>")
    end
  end
end
