# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UnderlineTag do
  let(:element_class) { Markbridge::AST::Underline }
  let(:empty_output) { "" }
  let(:simple_output) { "[u]hi[/u]" }
  let(:html_simple_output) { %(<span class="bbcode-u">hi</span>) }

  it_behaves_like "an inline wrapping tag"

  describe "#render content-shape branches" do
    let(:tag) { described_class.new }
    let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
    let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
    let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

    it "wraps non-whitespace content with [u]…[/u]" do
      element = element_class.new
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("[u]hi[/u]")
    end

    it "returns whitespace content unchanged when wrapping only line breaks" do
      # Underlining nothing visible (e.g. <u><br><br></u> from Word/Outlook
      # exports) should not produce a meaningless [u]\n\n[/u] in the output.
      element = element_class.new
      element << Markbridge::AST::LineBreak.new
      element << Markbridge::AST::LineBreak.new

      expect(tag.render(element, interface)).to eq("\n\n")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "wraps non-whitespace content with the bbcode-u span" do
        element = element_class.new
        element << Markbridge::AST::Text.new("hi")

        expect(tag.render(element, interface)).to eq(%(<span class="bbcode-u">hi</span>))
      end
    end

    # Discourse's BBCode plugin cooks `[u]…[/u]` from Markdown source but does
    # not re-process BBCode inside Markdown link text — `[[u]X[/u]](url)` stays
    # literal. Skip the wrapper when rendering inside a link.
    context "with a link ancestor in the parent chain" do
      it "returns content unwrapped when nested under Url" do
        url_parent = Markbridge::AST::Url.new(href: "https://example.com")
        link_context = Markbridge::Renderers::Discourse::RenderContext.new([url_parent])
        link_interface =
          Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, link_context)

        element = element_class.new
        element << Markbridge::AST::Text.new("Facebook")

        expect(tag.render(element, link_interface)).to eq("Facebook")
      end

      it "returns content unwrapped when nested under Email" do
        email_parent = Markbridge::AST::Email.new(address: "user@example.com")
        link_context = Markbridge::Renderers::Discourse::RenderContext.new([email_parent])
        link_interface =
          Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, link_context)

        element = element_class.new
        element << Markbridge::AST::Text.new("Contact")

        expect(tag.render(element, link_interface)).to eq("Contact")
      end
    end
  end
end
