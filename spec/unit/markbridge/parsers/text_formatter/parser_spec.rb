# frozen_string_literal: true

require "nokogiri"

RSpec.describe Markbridge::Parsers::TextFormatter::Parser do
  let(:parser) { described_class.new }

  describe "#initialize" do
    it "exposes unknown_tags as a counting hash defaulting to 0" do
      expect(parser.unknown_tags).to be_empty
      expect(parser.unknown_tags["never-seen"]).to eq(0)
    end

    it "falls back to the default registry when no handlers and no block are given" do
      doc = parser.parse("<r><B>x</B></r>")

      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
    end

    it "routes through a custom handlers registry when one is passed" do
      custom = Markbridge::Parsers::TextFormatter::HandlerRegistry.new
      custom.register(
        "B",
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      result = described_class.new(handlers: custom).parse("<r><B>x</B></r>")

      expect(result.children[0]).to be_a(Markbridge::AST::Italic)
    end

    it "invokes the block with the default registry and uses the resulting handlers" do
      result =
        described_class
          .new do |r|
            r.register(
              "B",
              Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler.new(
                Markbridge::AST::Italic,
              ),
            )
          end
          .parse("<r><B>x</B></r>")

      expect(result.children[0]).to be_a(Markbridge::AST::Italic)
    end
  end

  describe "#parse" do
    it "returns an AST::Document for a plain-text root <t> without tracking <t> as unknown" do
      doc = parser.parse("<t>hello</t>")

      expect(doc).to be_a(Markbridge::AST::Document)
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("hello")
      expect(parser.unknown_tags).to be_empty
    end

    it "processes children under rich-text root <r> without tracking <r> as unknown" do
      doc = parser.parse("<r><B>b</B><I>i</I></r>")

      expect(doc.children.map(&:class)).to eq([Markbridge::AST::Bold, Markbridge::AST::Italic])
      expect(parser.unknown_tags).to be_empty
    end

    it "skips markup-preservation elements <s> and <e>" do
      doc = parser.parse("<r><B><s>[b]</s>text<e>[/b]</e></B></r>")

      bold = doc.children[0]
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.map(&:class)).to eq([Markbridge::AST::Text])
      expect(bold.children[0].text).to eq("text")
    end

    it "emits a LineBreak node for <br> without tracking <br> as unknown" do
      doc = parser.parse("<r>a<br/>b</r>")

      expect(doc.children[1]).to be_a(Markbridge::AST::LineBreak)
      expect(parser.unknown_tags).to be_empty
    end

    it "drops whitespace-only text nodes" do
      doc = parser.parse("<r>   \n\t  </r>")

      expect(doc.children).to be_empty
    end

    it "keeps text nodes that contain any non-whitespace character" do
      doc = parser.parse("<r>  a  </r>")

      expect(doc.children.map(&:text)).to eq(["  a  "])
    end

    it "ignores comment nodes (neither element nor text)" do
      doc = parser.parse("<r><!-- skipme -->keep</r>")

      expect(doc.children.map(&:class)).to eq([Markbridge::AST::Text])
      expect(doc.children[0].text).to eq("keep")
    end

    it "tracks unknown tags in the unknown_tags counter" do
      parser.parse("<r><UNKNOWN>x</UNKNOWN><UNKNOWN>y</UNKNOWN></r>")

      expect(parser.unknown_tags["UNKNOWN"]).to eq(2)
    end

    it "still processes children of unknown tags" do
      doc = parser.parse("<r><UNKNOWN><B>b</B></UNKNOWN></r>")

      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
    end

    it "does not track a registered handler as unknown even when it returns nil" do
      void_handler =
        Class.new(Markbridge::Parsers::TextFormatter::Handlers::BaseHandler) do
          def process(element:, parent:, processor: nil)
            nil
          end
        end
      parser = described_class.new { |r| r.register("VOID", void_handler.new) }

      parser.parse("<r><VOID/></r>")

      expect(parser.unknown_tags).to be_empty
    end

    it "clears unknown_tags between parse calls" do
      parser.parse("<r><UNKNOWN/></r>")
      expect(parser.unknown_tags).not_to be_empty

      parser.parse("<r><B>b</B></r>")

      expect(parser.unknown_tags).to be_empty
    end

    it "treats invalid XML without a root as plain text (preserving the raw input)" do
      doc = parser.parse("no xml at all")

      expect(doc.children.map(&:class)).to eq([Markbridge::AST::Text])
      expect(doc.children[0].text).to eq("no xml at all")
    end

    it "returns an empty document when input is empty and has no root" do
      doc = parser.parse("")

      expect(doc.children).to be_empty
    end

    it "rescues Nokogiri::XML::SyntaxError and returns a Text node with the raw input" do
      allow(Nokogiri).to receive(:XML).and_raise(Nokogiri::XML::SyntaxError.new("broken"))

      doc = parser.parse("<malformed")

      expect(doc.children.map(&:class)).to eq([Markbridge::AST::Text])
      expect(doc.children[0].text).to eq("<malformed")
    end

    context "with pre-parsed Nokogiri input" do
      it "accepts a Nokogiri::XML::Document and unwraps it via #root" do
        xml_doc = Nokogiri.XML("<r><B>bold</B></r>")
        doc = parser.parse(xml_doc)

        expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
        expect(doc.children[0].children[0].text).to eq("bold")
      end

      it "accepts a Nokogiri::XML::Element directly as the root" do
        # Lets a caller hand in a sub-tree without re-wrapping it in a Document.
        element = Nokogiri.XML("<r><B>x</B></r>").root
        doc = parser.parse(element)

        expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
      end

      it "returns an empty document when a Document has no root" do
        # Edge case: a Document constructed but never given a root.
        xml_doc = Nokogiri::XML::Document.new
        doc = parser.parse(xml_doc)

        expect(doc.children).to be_empty
      end

      it "does not call Nokogiri.XML when given a pre-parsed Document" do
        # The whole point: hand in a tree the caller already parsed and
        # potentially mutated. Re-parsing it would defeat the purpose
        # (and re-introduce the URL-percent-encoding side effect that
        # importers work around).
        xml_doc = Nokogiri.XML("<r>x</r>")
        allow(Nokogiri).to receive(:XML)

        parser.parse(xml_doc)

        expect(Nokogiri).not_to have_received(:XML)
      end

      it "still coerces non-String, non-Nokogiri inputs via to_s" do
        coercible =
          Class.new do
            def to_s
              "<r><B>x</B></r>"
            end
          end
        doc = parser.parse(coercible.new)

        expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
      end

      it "unwraps any Nokogiri::XML::Document subclass via #root, not just exact instances" do
        # is_a?(Document) matches Nokogiri::HTML::Document (subclass);
        # instance_of?(Document) would not. Importers that accidentally
        # feed an HTML-parsed doc to the XML pipeline still get .root
        # called, rather than process_node-ing a Document (which is
        # silently a no-op because Document responds false to .element?).
        html_doc = Nokogiri::HTML.parse("<r/>")
        expect(html_doc).to be_a(Nokogiri::XML::Document)
        expect(html_doc).not_to be_instance_of(Nokogiri::XML::Document)
        allow(html_doc).to receive(:root).and_call_original

        parser.parse(html_doc)

        expect(html_doc).to have_received(:root)
      end
    end
  end

  describe "#process_children" do
    it "walks each child of the XML element and appends corresponding AST nodes to the parent" do
      xml = Nokogiri.XML("<r>text<B>bold</B></r>").root
      parent = Markbridge::AST::Document.new

      parser.process_children(xml, parent)

      expect(parent.children.map(&:class)).to eq([Markbridge::AST::Text, Markbridge::AST::Bold])
    end
  end

  describe "custom handlers that recurse manually" do
    it "passes element:, parent:, processor: and lets a handler recurse via processor.process_children" do
      wrap_handler =
        Class.new(Markbridge::Parsers::TextFormatter::Handlers::BaseHandler) do
          def initialize
            @element_class = Markbridge::AST::Bold
          end
          attr_reader :element_class

          def process(element:, parent:, processor:)
            wrapper = Markbridge::AST::Bold.new
            parent << wrapper
            processor.process_children(element, wrapper)
            nil # we recursed manually; don't double-process
          end
        end

      parser = described_class.new { |r| r.register("WRAP", wrap_handler.new) }

      doc = parser.parse("<r><WRAP><I>x</I></WRAP></r>")
      wrap = doc.children.first

      expect(wrap).to be_a(Markbridge::AST::Bold)
      expect(wrap.children.first).to be_a(Markbridge::AST::Italic)
    end
  end
end
