# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::SpanHandler do
  let(:parent) { Markbridge::AST::Document.new }
  let(:handler) { described_class.new }

  def fragment(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    context "when style attribute is missing or empty" do
      it "returns parent (passthrough) for span without style" do
        result = handler.process(element: fragment("<span>x</span>"), parent:)

        expect(result).to eq(parent)
        expect(parent.children).to be_empty
      end

      it "returns parent (passthrough) for span with empty style" do
        result = handler.process(element: fragment('<span style="">x</span>'), parent:)

        expect(result).to eq(parent)
        expect(parent.children).to be_empty
      end

      it "returns parent (passthrough) for span with unrecognized styles only" do
        node = fragment('<span style="color: red; padding: 4px">x</span>')

        result = handler.process(element: node, parent:)

        expect(result).to eq(parent)
        expect(parent.children).to be_empty
      end
    end

    context "with text-decoration: underline" do
      it "wraps children in Underline" do
        node = fragment('<span style="text-decoration: underline">x</span>')

        result = handler.process(element: node, parent:)

        expect(parent.children.size).to eq(1)
        expect(parent.children[0]).to be_a(Markbridge::AST::Underline)
        expect(result).to eq(parent.children[0])
      end

      it "is case-insensitive" do
        node = fragment('<span style="TEXT-DECORATION: UnderLine">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Underline)
      end

      it "handles trailing semicolon and whitespace" do
        node = fragment('<span style=" text-decoration : underline ; ">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Underline)
      end
    end

    context "with text-decoration: line-through" do
      it "wraps children in Strikethrough" do
        node = fragment('<span style="text-decoration: line-through">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Strikethrough)
      end
    end

    context "with text-decoration shorthand combining values" do
      it "wraps in both Underline and Strikethrough" do
        node = fragment('<span style="text-decoration: underline line-through">x</span>')

        result = handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Underline)
        expect(parent.children[0].children[0]).to be_a(Markbridge::AST::Strikethrough)
        expect(result).to eq(parent.children[0].children[0])
      end
    end

    context "with font-weight" do
      it "wraps in Bold for value 'bold'" do
        node = fragment('<span style="font-weight: bold">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Bold)
      end

      it "wraps in Bold for value 'bolder'" do
        node = fragment('<span style="font-weight: bolder">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Bold)
      end

      it "wraps in Bold when 'bold' has trailing whitespace before semicolon" do
        # The style regex captures everything up to `;`, leaving trailing
        # whitespace in the value — it must be stripped before equality
        # comparison.
        node = fragment('<span style="font-weight: bold ;">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Bold)
      end

      it "does not wrap for malformed numeric values like '700px'" do
        # Numeric weight must be a pure integer; reject strings like
        # `700px` even though `to_i` would yield 700.
        node = fragment('<span style="font-weight: 700px">x</span>')

        result = handler.process(element: node, parent:)

        expect(result).to eq(parent)
        expect(parent.children).to be_empty
      end

      it "wraps in Bold for numeric values >= 600" do
        node = fragment('<span style="font-weight: 700">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Bold)
      end

      it "wraps in Bold for the boundary value 600" do
        # Pin the threshold at >= 600; 600 must be bold, 599 must not.
        node = fragment('<span style="font-weight: 600">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Bold)
      end

      it "does not wrap for the boundary value 599" do
        node = fragment('<span style="font-weight: 599">x</span>')

        result = handler.process(element: node, parent:)

        expect(result).to eq(parent)
        expect(parent.children).to be_empty
      end

      it "does not wrap for numeric values < 600" do
        node = fragment('<span style="font-weight: 400">x</span>')

        result = handler.process(element: node, parent:)

        expect(result).to eq(parent)
        expect(parent.children).to be_empty
      end

      it "does not wrap for 'normal'" do
        node = fragment('<span style="font-weight: normal">x</span>')

        result = handler.process(element: node, parent:)

        expect(result).to eq(parent)
        expect(parent.children).to be_empty
      end
    end

    context "with font-style" do
      it "wraps in Italic for value 'italic'" do
        node = fragment('<span style="font-style: italic">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Italic)
      end

      it "wraps in Italic for value 'oblique'" do
        node = fragment('<span style="font-style: oblique">x</span>')

        handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Italic)
      end

      it "does not wrap for 'normal'" do
        node = fragment('<span style="font-style: normal">x</span>')

        result = handler.process(element: node, parent:)

        expect(result).to eq(parent)
        expect(parent.children).to be_empty
      end
    end

    context "with multiple recognized styles" do
      it "nests AST elements in declaration order" do
        node = fragment('<span style="font-weight: bold; text-decoration: underline">x</span>')

        result = handler.process(element: node, parent:)

        expect(parent.children[0]).to be_a(Markbridge::AST::Bold)
        expect(parent.children[0].children[0]).to be_a(Markbridge::AST::Underline)
        expect(result).to eq(parent.children[0].children[0])
      end

      it "does not double-wrap when the same class is implied twice" do
        # E.g. duplicate property in the cascade or via shorthand:
        # `text-decoration: underline; text-decoration: underline` must
        # produce one Underline, not Underline(Underline(...)).
        node =
          fragment('<span style="text-decoration: underline; text-decoration: underline">x</span>')

        result = handler.process(element: node, parent:)

        expect(parent.children.size).to eq(1)
        expect(parent.children[0]).to be_a(Markbridge::AST::Underline)
        expect(parent.children[0].children).to be_empty
        expect(result).to eq(parent.children[0])
      end
    end

    context "when rendered through the full pipeline" do
      it "renders <span style=\"text-decoration:underline\"><strong>X</strong></span> as [u]**X**[/u]" do
        result =
          Markbridge.html_to_markdown(
            '<span style="text-decoration: underline"><strong>X</strong></span>',
          )

        expect(result).to eq("[u]**X**[/u]")
      end
    end
  end
end
