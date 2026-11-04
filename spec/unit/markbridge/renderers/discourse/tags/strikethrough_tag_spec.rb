# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::StrikethroughTag do
  let(:element_class) { Markbridge::AST::Strikethrough }
  let(:empty_output) { "" }
  let(:simple_output) { "~~hi~~" }
  let(:html_simple_output) { "<s>hi</s>" }

  it_behaves_like "an inline wrapping tag"

  describe "#render" do
    let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
    let(:interface) do
      Markbridge::Renderers::Discourse::RenderingInterface.new(
        renderer,
        Markbridge::Renderers::Discourse::RenderContext.new,
      )
    end

    def strikethrough(text)
      Markbridge::AST::Strikethrough.new << Markbridge::AST::Text.new(text)
    end

    it "falls back to an s tag when the content starts with a tilde" do
      # `~~~x~~` would not close, and at the start of a line it opens a fence.
      expect(described_class.new.render(strikethrough("~x"), interface)).to eq("<s>~x</s>")
    end

    it "falls back to an s tag when the content ends with a tilde" do
      expect(described_class.new.render(strikethrough("x~"), interface)).to eq("<s>x~</s>")
    end

    it "looks past whitespace at the edges of the content" do
      expect(described_class.new.render(strikethrough(" ~x "), interface)).to eq("<s> ~x </s>")
    end

    it "uses tildes when the tilde is inside the content" do
      expect(described_class.new.render(strikethrough("a~b"), interface)).to eq("~~a~b~~")
    end
  end
end
