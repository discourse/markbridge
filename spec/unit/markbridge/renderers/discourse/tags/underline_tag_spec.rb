# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UnderlineTag do
  let(:element_class) { Markbridge::AST::Underline }
  let(:empty_output) { "" }
  let(:simple_output) { "[u]hi[/u]" }
  let(:html_simple_output) { %(<span class="bbcode-u">hi</span>) }

  it_behaves_like "an inline wrapping tag"

  describe "#render" do
    let(:tag) { described_class.new }
    let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
    let(:tokens) { Markbridge::Renderers::Discourse::Inline::Tokens }

    def element_with(text)
      element_class.new << Markbridge::AST::Text.new(text)
    end

    it "returns the children as tokens between the underline tokens" do
      interface =
        Markbridge::Renderers::Discourse::RenderingInterface.new(
          renderer,
          Markbridge::Renderers::Discourse::RenderContext.new,
        )

      expect(tag.render(element_with("hi"), interface)).to eq(
        [tokens.open(:u), tokens.raw("hi"), tokens.close(:u)],
      )
    end

    it "renders nothing visible without the wrapper" do
      # Underlining nothing visible (e.g. <u><br><br></u> from Word/Outlook
      # exports) should not produce a meaningless [u]\n\n[/u] in the output.
      element = element_class.new
      element << Markbridge::AST::LineBreak.new
      element << Markbridge::AST::LineBreak.new

      expect(renderer.render(element)).to eq("\n\n")
    end

    # Discourse's BBCode plugin cooks `[u]…[/u]` from Markdown source but does
    # not re-process BBCode inside Markdown link text — `[[u]X[/u]](url)` stays
    # literal. Skip the wrapper when rendering inside a link.
    context "with a link ancestor in the parent chain" do
      it "returns the children alone when nested under Url" do
        url_parent = Markbridge::AST::Url.new(href: "https://example.com")
        link_context = Markbridge::Renderers::Discourse::RenderContext.new([url_parent])
        link_interface =
          Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, link_context)

        expect(tag.render(element_with("Facebook"), link_interface)).to eq([tokens.raw("Facebook")])
      end

      it "returns the children alone when nested under Email" do
        email_parent = Markbridge::AST::Email.new(address: "user@example.com")
        link_context = Markbridge::Renderers::Discourse::RenderContext.new([email_parent])
        link_interface =
          Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, link_context)

        expect(tag.render(element_with("Contact"), link_interface)).to eq([tokens.raw("Contact")])
      end
    end
  end
end
