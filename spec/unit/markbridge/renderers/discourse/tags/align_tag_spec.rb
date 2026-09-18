# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::AlignTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  def align(alignment, *children)
    element = Markbridge::AST::Align.new(alignment:)
    children.each { |child| element << child }
    element
  end

  describe "#render" do
    %w[left right center justify].each do |alignment|
      it "wraps content in a div with align=#{alignment}" do
        element = align(alignment, Markbridge::AST::Text.new("hi"))

        expect(tag.render(element, interface)).to eq(
          %(\n\n<div align="#{alignment}">\n\nhi\n\n</div>\n\n),
        )
      end
    end

    it "isolates the content with blank lines so CommonMark parses it as Markdown" do
      element =
        align(
          "center",
          Markbridge::AST::Url
            .new(href: "https://example.com")
            .tap { |url| url << Markbridge::AST::Text.new("link") },
        )

      expect(tag.render(element, interface)).to eq(
        %(\n\n<div align="center">\n\n[link](https://example.com)\n\n</div>\n\n),
      )
    end

    it "trims the blank edges of content that brackets itself, keeping one blank line per side" do
      list = Markbridge::AST::List.new(ordered: false)
      list << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a"))
      element = align("center", list)

      expect(tag.render(element, interface)).to eq(%(\n\n<div align="center">\n\n- a\n\n</div>\n\n))
    end

    it "keeps the leading indentation of content that opens with a nested list item" do
      element = align("center", Markbridge::AST::MarkdownText.new("\n  - a\n  - b\n"))

      expect(tag.render(element, interface)).to eq(
        %(\n\n<div align="center">\n\n  - a\n  - b\n\n</div>\n\n),
      )
    end

    it "trims only blank edges, not the whitespace of a content line" do
      element = align("center", Markbridge::AST::MarkdownText.new("  padded  "))

      expect(tag.render(element, interface)).to eq(
        %(\n\n<div align="center">\n\n  padded  \n\n</div>\n\n),
      )
    end

    it "treats a blank-only body as empty" do
      element = align("center", Markbridge::AST::MarkdownText.new("\n  \n\n"))

      expect(tag.render(element, interface)).to eq(%(\n\n<div align="center"></div>\n\n))
    end

    it "treats a whitespace-only body as empty" do
      element = align("center", Markbridge::AST::MarkdownText.new("   "))

      expect(tag.render(element, interface)).to eq(%(\n\n<div align="center"></div>\n\n))
    end

    it "leaves the div empty rather than blank-padded when there is no content" do
      expect(tag.render(align("center"), interface)).to eq(%(\n\n<div align="center"></div>\n\n))
    end

    it "returns just the content when no alignment is set" do
      element = align(nil, Markbridge::AST::Text.new("hi"))

      expect(tag.render(element, interface)).to eq("hi")
    end

    it "drops the wrapper for unknown alignments to keep arbitrary input out of the attribute" do
      element = align(%(center" onclick="alert(1)), Markbridge::AST::Text.new("hi"))

      expect(tag.render(element, interface)).to eq("hi")
    end

    let(:element_class) { Markbridge::AST::Align }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "drops the blank lines so the surrounding HTML block stays intact" do
        element = align("center", Markbridge::AST::Text.new("hello"))

        expect(tag.render(element, interface)).to eq(%(<div align="center">hello</div>))
      end

      %w[left right center justify].each do |alignment|
        it "keeps the tight form for align=#{alignment}, whose children already render as HTML" do
          bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("hi")
          element = align(alignment, bold)

          expect(tag.render(element, interface)).to eq(
            %(<div align="#{alignment}"><strong>hi</strong></div>),
          )
        end
      end
    end
  end
end
