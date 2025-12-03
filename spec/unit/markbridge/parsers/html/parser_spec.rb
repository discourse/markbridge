# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Parser do
  let(:parser) { described_class.new }

  describe "#parse" do
    it "parses plain text" do
      doc = parser.parse("hello world")

      expect(doc).to be_a(Markbridge::AST::Document)
      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("hello world")
    end

    it "parses simple bold tag" do
      doc = parser.parse("<b>bold text</b>")

      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
      expect(doc.children[0].children[0].text).to eq("bold text")
    end

    it "parses nested tags" do
      doc = parser.parse("<b><i>nested</i></b>")

      bold = doc.children[0]
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children[0]).to be_a(Markbridge::AST::Italic)
      expect(bold.children[0].children[0].text).to eq("nested")
    end

    it "parses multiple tags" do
      doc = parser.parse("<b>bold</b> and <i>italic</i>")

      expect(doc.children.size).to eq(3)
      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
      expect(doc.children[1]).to be_a(Markbridge::AST::Text)
      expect(doc.children[1].text).to eq(" and ")
      expect(doc.children[2]).to be_a(Markbridge::AST::Italic)
    end

    it "handles line breaks" do
      doc = parser.parse("line 1<br>line 2")

      expect(doc.children.size).to eq(3)
      expect(doc.children[0].text).to eq("line 1")
      expect(doc.children[1]).to be_a(Markbridge::AST::LineBreak)
      expect(doc.children[2].text).to eq("line 2")
    end

    it "handles horizontal rules" do
      doc = parser.parse("text<hr>more")

      expect(doc.children.size).to eq(3)
      expect(doc.children[1]).to be_a(Markbridge::AST::HorizontalRule)
    end

    it "handles links with href" do
      doc = parser.parse('<a href="https://example.com">link</a>')

      link = doc.children[0]
      expect(link).to be_a(Markbridge::AST::Url)
      expect(link.href).to eq("https://example.com")
      expect(link.children[0].text).to eq("link")
    end

    it "handles images" do
      doc = parser.parse('<img src="photo.jpg" width="100" height="200">')

      img = doc.children[0]
      expect(img).to be_a(Markbridge::AST::Image)
      expect(img.src).to eq("photo.jpg")
      expect(img.width).to eq(100)
      expect(img.height).to eq(200)
    end

    it "handles unordered lists" do
      doc = parser.parse("<ul><li>item 1</li><li>item 2</li></ul>")

      list = doc.children[0]
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be false
      expect(list.children.size).to eq(2)
      expect(list.children[0]).to be_a(Markbridge::AST::ListItem)
      expect(list.children[1]).to be_a(Markbridge::AST::ListItem)
    end

    it "handles ordered lists" do
      doc = parser.parse("<ol><li>first</li><li>second</li></ol>")

      list = doc.children[0]
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be true
    end

    it "handles code blocks" do
      doc = parser.parse("<code>var x = 1;</code>")

      code = doc.children[0]
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children[0].text).to eq("var x = 1;")
    end

    it "handles blockquotes" do
      doc = parser.parse("<blockquote>quoted text</blockquote>")

      quote = doc.children[0]
      expect(quote).to be_a(Markbridge::AST::Quote)
      expect(quote.children[0].text).to eq("quoted text")
    end

    it "creates Paragraph nodes for paragraph tags" do
      doc = parser.parse("<p>paragraph text</p>")

      # Paragraph handler creates AST::Paragraph nodes
      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[0].children.size).to eq(1)
      expect(doc.children[0].children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].children[0].text).to eq("paragraph text")
    end

    it "preserves paragraph boundaries for adjacent paragraphs" do
      doc = parser.parse("<p>One</p><p>Two</p>")

      # Each paragraph should be a separate Paragraph node
      expect(doc.children.size).to eq(2)
      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[0].children[0].text).to eq("One")
      expect(doc.children[1]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[1].children[0].text).to eq("Two")
    end

    it "tracks unknown tags" do
      parser.parse("<unknown>text</unknown>")

      expect(parser.unknown_tags).to have_key("unknown")
      expect(parser.unknown_tags["unknown"]).to eq(1)
    end

    it "ignores unknown tags while processing their children" do
      doc = parser.parse("<unknown>content</unknown>")

      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("content")
    end

    it "handles malformed HTML gracefully" do
      doc = parser.parse("<b>bold <i>italic</b></i>")

      # Nokogiri fixes the nesting
      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
    end

    it "handles empty input" do
      doc = parser.parse("")

      expect(doc.children).to be_empty
    end

    it "decodes HTML entities in text" do
      doc = parser.parse("&lt;b&gt; &amp; &quot;text&quot;")

      expect(doc.children[0].text).to eq("<b> & \"text\"")
    end

    it "preserves whitespace" do
      doc = parser.parse("hello   world")

      expect(doc.children[0].text).to eq("hello   world")
    end
  end

  describe "#initialize" do
    it "accepts custom handlers" do
      custom_registry = Markbridge::Parsers::HTML::HandlerRegistry.new
      parser = described_class.new(handlers: custom_registry)

      expect(parser).to be_a(described_class)
    end

    it "accepts a block to customize handlers" do
      parser =
        described_class.new do |registry|
          # Block is called with registry
          expect(registry).to be_a(Markbridge::Parsers::HTML::HandlerRegistry)
        end

      expect(parser).to be_a(described_class)
    end

    it "uses default handlers when none provided" do
      parser = described_class.new

      doc = parser.parse("<b>test</b>")
      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
    end
  end
end
