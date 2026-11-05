# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::StrikethroughTag do
  let(:element_class) { Markbridge::AST::Strikethrough }
  let(:empty_output) { "" }
  let(:simple_output) { "~~hi~~" }
  let(:html_simple_output) { "<s>hi</s>" }

  it_behaves_like "an inline wrapping tag"

  it "returns the children as tokens between the strikethrough tokens" do
    element = Markbridge::AST::Strikethrough.new << Markbridge::AST::Text.new("a~b")
    tokens = Markbridge::Renderers::Discourse::Inline::Tokens
    interface =
      Markbridge::Renderers::Discourse::RenderingInterface.new(
        Markbridge::Renderers::Discourse::Renderer.new,
        Markbridge::Renderers::Discourse::RenderContext.new,
      )

    expect(described_class.new.render(element, interface)).to eq(
      [tokens.open(:s), tokens.raw("a~b"), tokens.close(:s)],
    )
  end
end
