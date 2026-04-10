# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::MediaWiki::Parser do
  let(:parser) { described_class.new }

  def parse(input)
    parser.parse(input)
  end

  describe "plain text" do
    it "parses plain text" do
      doc = parse("hello world")
      expect(doc.children.size).to eq(1)
      paragraph = doc.children.first
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      expect(paragraph.children.first).to be_a(Markbridge::AST::Text)
      expect(paragraph.children.first.text).to eq("hello world")
    end

    it "handles empty string" do
      doc = parse("")
      expect(doc.children).to be_empty
    end
  end

  describe "line ending normalization" do
    it "normalizes CRLF line endings" do
      doc = parse("== Heading ==\r\ntext")
      expect(doc.children.first).to be_a(Markbridge::AST::Heading)
    end

    it "normalizes CR line endings" do
      doc = parse("== Heading ==\rtext")
      expect(doc.children.first).to be_a(Markbridge::AST::Heading)
    end
  end

  describe "headings" do
    it "parses level 1 heading" do
      doc = parse("= Heading 1 =")
      heading = doc.children.first
      expect(heading).to be_a(Markbridge::AST::Heading)
      expect(heading.level).to eq(1)
      expect(heading.children.first.text).to eq("Heading 1")
    end

    it "parses level 2 heading" do
      doc = parse("== Heading 2 ==")
      heading = doc.children.first
      expect(heading).to be_a(Markbridge::AST::Heading)
      expect(heading.level).to eq(2)
      expect(heading.children.first.text).to eq("Heading 2")
    end

    it "parses level 3 heading" do
      doc = parse("=== Heading 3 ===")
      heading = doc.children.first
      expect(heading.level).to eq(3)
    end

    it "parses level 4 heading" do
      doc = parse("==== Heading 4 ====")
      heading = doc.children.first
      expect(heading.level).to eq(4)
    end

    it "parses level 5 heading" do
      doc = parse("===== Heading 5 =====")
      heading = doc.children.first
      expect(heading.level).to eq(5)
    end

    it "parses level 6 heading" do
      doc = parse("====== Heading 6 ======")
      heading = doc.children.first
      expect(heading.level).to eq(6)
    end

    it "allows trailing whitespace on headings" do
      doc = parse("== Heading ==  ")
      heading = doc.children.first
      expect(heading).to be_a(Markbridge::AST::Heading)
      expect(heading.children.first.text).to eq("Heading")
    end

    it "parses inline formatting within headings" do
      doc = parse("== '''Bold''' Heading ==")
      heading = doc.children.first
      expect(heading.children.first).to be_a(Markbridge::AST::Bold)
    end
  end

  describe "horizontal rules" do
    it "parses ---- as horizontal rule" do
      doc = parse("----")
      expect(doc.children.first).to be_a(Markbridge::AST::HorizontalRule)
    end

    it "parses longer dashes as horizontal rule" do
      doc = parse("------")
      expect(doc.children.first).to be_a(Markbridge::AST::HorizontalRule)
    end

    it "allows trailing whitespace" do
      doc = parse("----  ")
      expect(doc.children.first).to be_a(Markbridge::AST::HorizontalRule)
    end
  end

  describe "unordered lists" do
    it "parses single-level list" do
      doc = parse("* Item 1\n* Item 2\n* Item 3")
      list = doc.children.first
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be false
      expect(list.children.size).to eq(3)
      expect(list.children[0].children.first.text).to eq("Item 1")
      expect(list.children[1].children.first.text).to eq("Item 2")
      expect(list.children[2].children.first.text).to eq("Item 3")
    end

    it "parses nested list" do
      doc = parse("* Item 1\n** Sub-item\n* Item 2")
      list = doc.children.first
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.children.size).to eq(2)

      # First item has a nested list
      first_item = list.children[0]
      nested_list = first_item.children.last
      expect(nested_list).to be_a(Markbridge::AST::List)
      expect(nested_list.children.first.children.first.text).to eq("Sub-item")
    end
  end

  describe "ordered lists" do
    it "parses single-level ordered list" do
      doc = parse("# First\n# Second\n# Third")
      list = doc.children.first
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be true
      expect(list.children.size).to eq(3)
    end

    it "parses nested ordered list" do
      doc = parse("# Item\n## Sub-item")
      list = doc.children.first
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be true

      nested = list.children.first.children.last
      expect(nested).to be_a(Markbridge::AST::List)
      expect(nested.ordered?).to be true
    end
  end

  describe "mixed lists" do
    it "handles switching from unordered to ordered" do
      doc = parse("* Bullet\n# Number")
      expect(doc.children.size).to eq(2)
      expect(doc.children[0]).to be_a(Markbridge::AST::List)
      expect(doc.children[0].ordered?).to be false
      expect(doc.children[1]).to be_a(Markbridge::AST::List)
      expect(doc.children[1].ordered?).to be true
    end
  end

  describe "preformatted text" do
    it "parses lines starting with space as preformatted" do
      doc = parse(" preformatted line")
      code = doc.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("preformatted line")
    end

    it "groups consecutive preformatted lines" do
      doc = parse(" line 1\n line 2\n line 3")
      code = doc.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("line 1\nline 2\nline 3")
    end
  end

  describe "<pre> blocks" do
    it "parses <pre>...</pre> block" do
      doc = parse("<pre>code here</pre>")
      code = doc.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("code here")
    end

    it "parses multi-line <pre> block" do
      doc = parse("<pre>\nline 1\nline 2\n</pre>")
      code = doc.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("\nline 1\nline 2\n")
    end
  end

  describe "inline formatting in text lines" do
    it "parses bold in text" do
      doc = parse("This is '''bold''' text")
      paragraph = doc.children.first
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      expect(paragraph.children[1]).to be_a(Markbridge::AST::Bold)
    end

    it "parses italic in text" do
      doc = parse("This is ''italic'' text")
      paragraph = doc.children.first
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      expect(paragraph.children[1]).to be_a(Markbridge::AST::Italic)
    end

    it "parses links in text" do
      doc = parse("See [[Main Page]]")
      paragraph = doc.children.first
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      expect(paragraph.children[1]).to be_a(Markbridge::AST::Url)
    end
  end

  describe "blank lines" do
    it "separates content around blank lines" do
      doc = parse("== Heading ==\n\ntext after")
      expect(doc.children[0]).to be_a(Markbridge::AST::Heading)
      paragraph = doc.children[1]
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      expect(paragraph.children.first.text).to eq("text after")
    end

    it "preserves text on both sides of blank lines" do
      doc = parse("text 1\n\ntext 2")
      paragraphs = doc.children.select { |c| c.is_a?(Markbridge::AST::Paragraph) }
      expect(paragraphs.size).to eq(2)
      expect(paragraphs[0].children.first.text).to eq("text 1")
      expect(paragraphs[1].children.first.text).to eq("text 2")
    end
  end

  describe "complex documents" do
    it "parses a mixed document" do
      input = <<~WIKI.chomp
        == Introduction ==
        This is '''bold''' and ''italic'' text.
        ----
        * Item 1
        * Item 2
        # Numbered
      WIKI

      doc = parse(input)
      expect(doc.children[0]).to be_a(Markbridge::AST::Heading)
      # Text content follows the heading
      expect(doc.children).to include(an_instance_of(Markbridge::AST::HorizontalRule))
    end
  end

  describe "constructor customization" do
    it "accepts a custom inline_tag_registry" do
      registry = Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
        r.register("mark", :formatting, Markbridge::AST::Bold)
      end
      parser = described_class.new(inline_tag_registry: registry)
      doc = parser.parse("<mark>highlighted</mark>")

      paragraph = doc.children.first
      expect(paragraph.children.first).to be_a(Markbridge::AST::Bold)
    end

    it "accepts a block for registry customization" do
      parser = described_class.new do |r|
        r.register("mark", :formatting, Markbridge::AST::Bold)
      end
      doc = parser.parse("<mark>highlighted</mark>")

      paragraph = doc.children.first
      expect(paragraph.children.first).to be_a(Markbridge::AST::Bold)
    end
  end
end
