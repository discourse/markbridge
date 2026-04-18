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

    it "treats a single word with no whitespace as non-blank content" do
      doc = parse("hello")
      expect(doc.children.first).to be_a(Markbridge::AST::Paragraph)
    end

    it "treats a tab-only line (no leading space) as blank: closes lists but emits nothing" do
      doc = parse("* item\n\t")
      # List is closed, tab line emits no paragraph
      expect(doc.children.map(&:class)).to eq([Markbridge::AST::List])
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

    it "normalizes every Unicode line separator in the input, not just the first" do
      doc = parse("== H1 ==\u2028== H2 ==\u2028== H3 ==")

      headings = doc.children.select { |c| c.is_a?(Markbridge::AST::Heading) }
      expect(headings.size).to eq(3)
    end

    it "normalizes Unicode line/paragraph separators" do
      doc = parse("== H1 ==\u2028text")
      expect(doc.children.first).to be_a(Markbridge::AST::Heading)
    end

    it "collapses consecutive Unicode line separators into a single newline" do
      doc = parse("* item1\u2028\u2028* item2")

      # With the `+` quantifier, the pair collapses to one \n so items stay in one list.
      # Without it, they become a blank line and split the list into two.
      lists = doc.children.select { |c| c.is_a?(Markbridge::AST::List) }
      expect(lists.size).to eq(1)
      expect(lists[0].children.size).to eq(2)
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

    it "parses unbalanced =foo (no closing =) as a heading" do
      doc = parse("= foo")
      expect(doc.children.first).to be_a(Markbridge::AST::Heading)
    end

    it "strips trailing whitespace from unbalanced heading content" do
      doc = parse("= foo   ")
      expect(doc.children.first.children.first.text).to eq("foo")
    end

    it "parses =a= without surrounding spaces as a heading" do
      doc = parse("=a=")
      expect(doc.children.first).to be_a(Markbridge::AST::Heading)
    end

    it "parses a heading whose content contains inner = signs" do
      doc = parse("== a=b ==")
      expect(doc.children.first).to be_a(Markbridge::AST::Heading)
    end

    it "parses a heading of `= = =` (only whitespace and equals)" do
      doc = parse("= = =")
      expect(doc.children.first).to be_a(Markbridge::AST::Heading)
    end

    it "does not treat 7 or more leading = as a heading" do
      doc = parse("======= foo =======")
      expect(doc.children.first).not_to be_a(Markbridge::AST::Heading)
    end

    it "does not treat a line of only = signs as a heading" do
      doc = parse("==")
      expect(doc.children.first).not_to be_a(Markbridge::AST::Heading)
    end

    it "does not treat `=foo=bar` (inner = without proper close) as a heading" do
      doc = parse("=foo=bar")
      expect(doc.children.first).not_to be_a(Markbridge::AST::Heading)
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
    it "strips trailing whitespace from list-item content" do
      doc = parse("* item   ")

      item = doc.children.first.children.first
      expect(item.children.first.text).to eq("item")
    end

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

    it "keeps consecutive items at the same depth in the same list" do
      doc = parse("* Item 1\n** Sub 1\n** Sub 2")

      nested_list = doc.children.first.children[0].children.last
      expect(nested_list).to be_a(Markbridge::AST::List)
      expect(nested_list.children.size).to eq(2)
    end

    it "opens a fresh stack of nested lists when an item starts deep without a parent at that depth" do
      doc = parse("** Sub 1")

      # One outer list at the document level; one nested list inside its auto-created item.
      expect(doc.children.size).to eq(1)
      outer = doc.children.first
      expect(outer).to be_a(Markbridge::AST::List)
      expect(outer.children.size).to eq(1)
      nested = outer.children[0].children.last
      expect(nested).to be_a(Markbridge::AST::List)
      expect(nested.children.size).to eq(1)
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

    it "recognises <pre> even when preceded by whitespace" do
      doc = parse("\t<pre>code</pre>")
      expect(doc.children.first).to be_a(Markbridge::AST::Code)
    end

    it "recognises case-insensitive <PRE>" do
      doc = parse("<PRE>code</PRE>")
      expect(doc.children.first).to be_a(Markbridge::AST::Code)
    end

    it "falls back to consuming to end of input when no </pre> is found" do
      doc = parse("<pre>unterminated\nmore content\nand more")

      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Code)
      expect(doc.children.first.children.first.text).to eq("unterminated\nmore content\nand more")
    end

    it "resumes normal parsing on the line after </pre> when there is trailing content" do
      doc = parse("<pre>code</pre>\nafter")

      expect(doc.children.size).to eq(2)
      expect(doc.children[0]).to be_a(Markbridge::AST::Code)
      expect(doc.children[1]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[1].children.first.text).to eq("after")
    end

    it "handles a <pre> block that starts after other content" do
      doc = parse("before\n<pre>code</pre>")

      expect(doc.children.size).to eq(2)
      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[1]).to be_a(Markbridge::AST::Code)
      expect(doc.children[1].children.first.text).to eq("code")
    end

    it "handles an unterminated <pre> block that starts after other content" do
      doc = parse("before\n<pre>code")

      expect(doc.children.size).to eq(2)
      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[1]).to be_a(Markbridge::AST::Code)
      expect(doc.children[1].children.first.text).to eq("code")
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

  describe "list reset" do
    it "starts a fresh list after a paragraph interrupts the list" do
      doc = parse("* item1\n\ntext\n* item2")

      lists = doc.children.select { |c| c.is_a?(Markbridge::AST::List) }
      expect(lists.size).to eq(2)
      expect(lists[0].children.size).to eq(1)
      expect(lists[1].children.size).to eq(1)
    end

    it "starts a fresh list after a blank line" do
      doc = parse("* item1\n\n* item2")

      lists = doc.children.select { |c| c.is_a?(Markbridge::AST::List) }
      expect(lists.size).to eq(2)
    end

    it "starts a fresh list after a heading" do
      doc = parse("* item1\n== heading ==\n* item2")

      lists = doc.children.select { |c| c.is_a?(Markbridge::AST::List) }
      expect(lists.size).to eq(2)
    end

    it "starts a fresh list after a horizontal rule" do
      doc = parse("* item1\n----\n* item2")

      lists = doc.children.select { |c| c.is_a?(Markbridge::AST::List) }
      expect(lists.size).to eq(2)
    end

    it "starts a fresh list after a preformatted block" do
      doc = parse("* item1\n preformatted\n* item2")

      lists = doc.children.select { |c| c.is_a?(Markbridge::AST::List) }
      expect(lists.size).to eq(2)
    end

    it "starts a fresh list after a <pre> block" do
      doc = parse("* item1\n<pre>code</pre>\n* item2")

      lists = doc.children.select { |c| c.is_a?(Markbridge::AST::List) }
      expect(lists.size).to eq(2)
    end

    it "starts a fresh list after an inline paragraph with no blank line between" do
      doc = parse("* item1\ntext\n* item2")

      lists = doc.children.select { |c| c.is_a?(Markbridge::AST::List) }
      expect(lists.size).to eq(2)
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
end
