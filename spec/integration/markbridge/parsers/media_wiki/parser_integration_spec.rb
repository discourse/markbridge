# frozen_string_literal: true

RSpec.describe "MediaWiki Parser Integration" do
  let(:parser) { Markbridge::Parsers::MediaWiki::Parser.new }

  def parse(input)
    parser.parse(input)
  end

  describe "full document parsing" do
    it "parses a complete MediaWiki document" do
      input = <<~WIKI.chomp
        = Main Title =

        This is a paragraph with '''bold''' and ''italic'' text.

        == Section ==
        Some text with a [[link]] and [https://example.com external link].

        * Bullet one
        * Bullet two
        ** Nested bullet

        # First
        # Second

        ----

         preformatted line 1
         preformatted line 2

        === Subsection ===
        Text with <code>inline code</code> and <s>strikethrough</s>.
      WIKI

      doc = parse(input)
      expect(doc).to be_a(Markbridge::AST::Document)

      # Should contain various node types
      node_classes = collect_node_classes(doc)
      expect(node_classes).to include(Markbridge::AST::Heading)
      expect(node_classes).to include(Markbridge::AST::Bold)
      expect(node_classes).to include(Markbridge::AST::Italic)
      expect(node_classes).to include(Markbridge::AST::Url)
      expect(node_classes).to include(Markbridge::AST::List)
      expect(node_classes).to include(Markbridge::AST::ListItem)
      expect(node_classes).to include(Markbridge::AST::HorizontalRule)
      expect(node_classes).to include(Markbridge::AST::Code)
      expect(node_classes).to include(Markbridge::AST::Strikethrough)
    end
  end

  describe "bold and italic interactions" do
    it "handles italic inside bold" do
      doc = parse("'''bold and ''italic'' text'''")
      paragraph = doc.children.first
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      bold = paragraph.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children[1]).to be_a(Markbridge::AST::Italic)
    end

    it "handles bold italic combined" do
      doc = parse("'''''bold and italic'''''")
      paragraph = doc.children.first
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      bold = paragraph.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("bold and italic")
    end
  end

  describe "lists with inline formatting" do
    it "parses list items with bold and links" do
      input = "* '''Important''' item\n* Item with [[Page|link]]"
      doc = parse(input)
      list = doc.children.first

      expect(list).to be_a(Markbridge::AST::List)
      expect(list.children.size).to eq(2)

      # First item has bold
      first_item = list.children[0]
      expect(first_item.children.first).to be_a(Markbridge::AST::Bold)

      # Second item has a link
      second_item = list.children[1]
      expect(second_item.children[1]).to be_a(Markbridge::AST::Url)
    end
  end

  describe "deeply nested lists" do
    it "parses three levels of nesting" do
      input = "* Level 1\n** Level 2\n*** Level 3"
      doc = parse(input)

      list1 = doc.children.first
      expect(list1).to be_a(Markbridge::AST::List)

      list2 = list1.children.first.children.last
      expect(list2).to be_a(Markbridge::AST::List)

      list3 = list2.children.first.children.last
      expect(list3).to be_a(Markbridge::AST::List)
      expect(list3.children.first.children.first.text).to eq("Level 3")
    end
  end

  describe "nowiki blocks" do
    it "preserves wiki markup as literal text" do
      doc = parse("Text <nowiki>'''not bold''' and [[not a link]]</nowiki> more")
      paragraph = doc.children.first
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      texts = paragraph.children.select { |c| c.is_a?(Markbridge::AST::Text) }
      combined = texts.map(&:text).join
      expect(combined).to include("'''not bold'''")
      expect(combined).to include("[[not a link]]")
    end
  end

  describe "headings with inline content" do
    it "parses headings containing links" do
      doc = parse("== See [[Main Page]] ==")
      heading = doc.children.first
      expect(heading).to be_a(Markbridge::AST::Heading)
      expect(heading.level).to eq(2)
      expect(heading.children[1]).to be_a(Markbridge::AST::Url)
    end
  end

  describe "preformatted blocks" do
    it "collects consecutive preformatted lines" do
      input = " line 1\n line 2\n line 3"
      doc = parse(input)
      code = doc.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("line 1\nline 2\nline 3")
    end

    it "separates preformatted blocks from regular text" do
      input = "normal\n preformatted\nnormal again"
      doc = parse(input)

      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[1]).to be_a(Markbridge::AST::Code)
      expect(doc.children[2]).to be_a(Markbridge::AST::Paragraph)
    end
  end

  private

  # Recursively collect all node classes in the AST.
  def collect_node_classes(node, classes = Set.new)
    classes << node.class
    if node.respond_to?(:children)
      node.children.each { |child| collect_node_classes(child, classes) }
    end
    classes
  end
end
