# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::AlignTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    %w[left right center justify].each do |alignment|
      it "wraps content in a div styled with text-align: #{alignment}" do
        element = Markbridge::AST::Align.new(alignment:)
        element << Markbridge::AST::Text.new("hi")

        expect(tag.render(element, interface)).to eq(
          %(<div style="text-align: #{alignment}">hi</div>\n\n),
        )
      end
    end

    it "returns just the content when no alignment is set" do
      element = Markbridge::AST::Align.new
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("hi")
    end

    it "drops the wrapper for unknown alignments to avoid CSS injection via inline style" do
      element =
        Markbridge::AST::Align.new(alignment: "center; background: url(javascript:alert(1))")
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("hi")
    end

    let(:element_class) { Markbridge::AST::Align }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "drops the trailing blank line so the surrounding HTML block stays intact" do
        element = Markbridge::AST::Align.new(alignment: "center")
        element << Markbridge::AST::Text.new("hello")

        expect(tag.render(element, interface)).to eq(%(<div style="text-align: center">hello</div>))
      end
    end
  end
end
