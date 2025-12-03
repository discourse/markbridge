# frozen_string_literal: true

require "nokogiri"

RSpec.describe Markbridge::Parsers::TextFormatter::Parser do
  let(:parser) { described_class.new }

  describe "parsing s9e/TextFormatter XML" do
    it "parses basic formatting from documentation example" do
      xml =
        '<r><URL url="http://example.org"><s>[url=http://example.org]</s>Go to example.org<e>[/url]</e></URL><br/><URL url="http://example.org">http://example.org</URL></r>'

      result = parser.parse(xml)

      expect(result).to be_a(Markbridge::AST::Document)
      urls = result.children.select { |c| c.is_a?(Markbridge::AST::Url) }
      line_breaks = result.children.select { |c| c.is_a?(Markbridge::AST::LineBreak) }

      expect(urls.size).to eq(2)
      expect(line_breaks.size).to eq(1)
      expect(urls.first.href).to eq("http://example.org")
    end

    it "parses plain text" do
      xml = "<t>Plain &amp; boring text.</t>"

      result = parser.parse(xml)

      expect(result.children.size).to eq(1)
      expect(result.children.first).to be_a(Markbridge::AST::Text)
      expect(result.children.first.text).to eq("Plain & boring text.")
    end

    it "parses rich text with bold and italic" do
      xml = "<r><B>bold</B> and <I>italic</I></r>"

      result = parser.parse(xml)

      bold = result.children.find { |c| c.is_a?(Markbridge::AST::Bold) }
      italic = result.children.find { |c| c.is_a?(Markbridge::AST::Italic) }

      expect(bold).not_to be_nil
      expect(italic).not_to be_nil
      expect(bold.children.first.text).to eq("bold")
      expect(italic.children.first.text).to eq("italic")
    end

    it "parses nested formatting" do
      xml = "<r><B><I>bold and italic</I></B></r>"

      result = parser.parse(xml)

      bold = result.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("bold and italic")
    end

    it "parses code with language" do
      xml = '<r><CODE lang="ruby">puts "hello"</CODE></r>'

      result = parser.parse(xml)

      code = result.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.language).to eq("ruby")
      expect(code.children.first.text).to eq('puts "hello"')
    end

    it "parses quote with author" do
      xml = '<r><QUOTE author="John">quoted text</QUOTE></r>'

      result = parser.parse(xml)

      quote = result.children.first
      expect(quote).to be_a(Markbridge::AST::Quote)
      expect(quote.author).to eq("John")
      expect(quote.children.first.text).to eq("quoted text")
    end

    it "parses lists" do
      xml = '<r><LIST type="1"><LI>First</LI><LI>Second</LI></LIST></r>'

      result = parser.parse(xml)

      list = result.children.first
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be true
      expect(list.children.size).to eq(2)
      expect(list.children.all? { |c| c.is_a?(Markbridge::AST::ListItem) }).to be true
    end

    it "parses paragraphs while preserving nested formatting" do
      xml = <<~XML
        <r><p>Hello <B>world</B>!</p><p>Second paragraph</p></r>
      XML

      result = parser.parse(xml)

      expect(result.children.size).to eq(2)
      expect(result.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(result.children[1]).to be_a(Markbridge::AST::Paragraph)

      first_paragraph = result.children[0]
      bold = first_paragraph.children.find { |child| child.is_a?(Markbridge::AST::Bold) }

      expect(bold).not_to be_nil
      expect(bold.children.first.text).to eq("world")
      expect(first_paragraph.children.map(&:class)).to include(Markbridge::AST::Text)
    end

    it "parses complex phpBB post" do
      xml = <<~XML
        <r><p>Hello <B>world</B>!</p>
        <QUOTE author="User1">This is a quote</QUOTE>
        <p>Check <URL url="https://example.org">this link</URL>.</p></r>
      XML

      result = parser.parse(xml)

      expect(result.children.map(&:class)).to eq(
        [Markbridge::AST::Paragraph, Markbridge::AST::Quote, Markbridge::AST::Paragraph],
      )

      first_paragraph = result.children[0]
      quote = result.children[1]
      second_paragraph = result.children[2]

      expect(
        first_paragraph.children.any? { |child| child.is_a?(Markbridge::AST::Bold) },
      ).to be true
      expect(quote).to be_a(Markbridge::AST::Quote)
      expect(quote.author).to eq("User1")
      expect(
        second_paragraph.children.any? { |child| child.is_a?(Markbridge::AST::Url) },
      ).to be true
    end

    it "ignores markup preservation elements" do
      xml =
        '<r><URL url="http://example.org"><s>[url=http://example.org]</s>text<e>[/url]</e></URL></r>'

      result = parser.parse(xml)

      url = result.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      # Should only have text child, not <s> and <e> elements
      expect(url.children.size).to eq(1)
      expect(url.children.first.text).to eq("text")
    end

    it "tracks unknown elements" do
      xml = "<r><UNKNOWN>text</UNKNOWN></r>"

      result = parser.parse(xml)

      expect(parser.unknown_tags["UNKNOWN"]).to eq(1)
    end

    it "ignores unknown elements while processing their children" do
      xml = "<r><UNKNOWN>content here</UNKNOWN></r>"

      result = parser.parse(xml)

      # Unknown element should contribute its children without wrapper text
      expect(result.children.size).to eq(1)
      expect(result.children.first).to be_a(Markbridge::AST::Text)
      expect(result.children.first.text).to eq("content here")
    end

    it "ignores unknown elements with attributes while preserving children" do
      xml = '<r><CUSTOM attr="value">text</CUSTOM></r>'

      result = parser.parse(xml)

      text_node = result.children.first
      expect(text_node).to be_a(Markbridge::AST::Text)
      expect(text_node.text).to eq("text")
    end

    it "handles malformed XML gracefully" do
      xml = "<r><unclosed>text"

      result = parser.parse(xml)

      expect(result).to be_a(Markbridge::AST::Document)
      # Nokogiri may auto-close or treat as text, either is acceptable
      expect(result.children).not_to be_empty
    end

    it "treats plain text input as text" do
      xml = "Not valid XML at all"

      result = parser.parse(xml)

      expect(result).to be_a(Markbridge::AST::Document)
      expect(result.children.size).to eq(1)
      expect(result.children.first).to be_a(Markbridge::AST::Text)
      expect(result.children.first.text).to eq("Not valid XML at all")
    end

    it "handles empty input" do
      xml = ""

      result = parser.parse(xml)

      expect(result).to be_a(Markbridge::AST::Document)
      expect(result.children).to be_empty
    end
  end
end
