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

  # Loop-progress guard: process_lines must advance `i` every
  # iteration. The block-reassigning branches (process_preformatted_block,
  describe "tables" do
    def parse_table(wikitext)
      doc = parser.parse(wikitext)
      doc.children.first
    end

    let(:parser) { described_class.new }

    it "parses a minimal table with a header row" do
      table = parse_table("{|\n! A !! B\n|}")

      expect(table).to be_a(Markbridge::AST::Table)
      expect(table.children.size).to eq(1)

      row = table.children.first
      expect(row).to be_a(Markbridge::AST::TableRow)
      expect(row.children.size).to eq(2)
      expect(row.children.map(&:header?)).to eq([true, true])
      expect(row.children[0].children.first.text).to eq("A")
      expect(row.children[1].children.first.text).to eq("B")
    end

    it "splits `|| data cells` within one data line" do
      table = parse_table("{|\n| 1 || 2 || 3\n|}")

      row = table.children.first
      expect(row.children.size).to eq(3)
      expect(row.children.map(&:header?)).to eq([false, false, false])
      expect(row.children.map { |c| c.children.first.text }).to eq(%w[1 2 3])
    end

    it "splits `!! header cells` within one header line" do
      table = parse_table("{|\n! x !! y !! z\n|}")

      row = table.children.first
      expect(row.children.size).to eq(3)
      expect(row.children.map(&:header?)).to eq([true, true, true])
    end

    it "creates a new row on `|-` separators" do
      table = parse_table("{|\n| 1\n|-\n| 2\n|-\n| 3\n|}")

      expect(table.children.size).to eq(3)
      expect(table.children.flat_map(&:children).map { |c| c.children.first.text }).to eq(%w[1 2 3])
    end

    it "puts each stand-alone data line in its own row when separated by `|-`" do
      table = parse_table("{|\n| 1\n| 2\n|-\n| 3\n|}")

      # Without a `|-` between lines 1 and 2, they share a row.
      expect(table.children.size).to eq(2)
      expect(table.children[0].children.size).to eq(2)
      expect(table.children[1].children.size).to eq(1)
    end

    it "treats `|-` before any cells as a no-op" do
      table = parse_table("{|\n|-\n| 1\n|}")

      expect(table.children.size).to eq(1)
      expect(table.children.first.children.size).to eq(1)
    end

    it "ignores lines that don't start with `!`, `|`, or `|-`" do
      table = parse_table("{|\nclass=\"foo\"\n| 1\n|}")

      expect(table.children.size).to eq(1)
      expect(table.children.first.children.first.children.first.text).to eq("1")
    end

    it "stops at the closing `|}` and leaves following content alone" do
      doc = parser.parse("{|\n| 1\n|}\nafter")

      expect(doc.children[0]).to be_a(Markbridge::AST::Table)
      expect(doc.children[1]).to be_a(Markbridge::AST::Paragraph)
    end

    it "preserves pipes inside [[target|display]] when splitting cells" do
      table = parse_table("{|\n| [[Page|Home]] || trailing\n|}")

      row = table.children.first
      expect(row.children.size).to eq(2)
      # First cell contains the full Url target with "Home" display
      url = row.children.first.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("Page")
      expect(url.children.first.text).to eq("Home")
      expect(row.children[1].children.first.text).to eq("trailing")
    end

    it "preserves pipes inside nested [[ [[ ]] ]] markers" do
      table = parse_table("{|\n| [[Outer|[[Inner|X]]]] || after\n|}")

      row = table.children.first
      expect(row.children.size).to eq(2)
      expect(row.children[1].children.first.text).to eq("after")
    end

    it "treats a `|-` after `|` or `!` as row separator, not a cell" do
      # Two explicit headers separated by `|-`
      table = parse_table("{|\n! A\n|-\n! B\n|}")

      expect(table.children.size).to eq(2)
      expect(table.children[0].children.first.children.first.text).to eq("A")
      expect(table.children[1].children.first.children.first.text).to eq("B")
    end

    it "allows attribute-pipe inside a cell (keeps only the content after the first `|`)" do
      # A single `|` inside a cell separates attrs from content.
      table = parse_table('{|\n| class="x" | value\n|}'.gsub('\n', "\n"))

      row = table.children.first
      expect(row.children.size).to eq(1)
      expect(row.children.first.children.first.text).to eq("value")
    end

    it "does not re-process lines before the `{|` when a prior `|}` appears as text" do
      # Covers `i = start_index + 1` — start of table iteration must
      # skip the `{|` line itself, not restart from an earlier line
      # whose text happens to begin with `|}`.
      doc = parser.parse("dummy\n|} gotcha\n{|\n| x\n|}")

      expect(doc.children.map(&:class)).to eq(
        [Markbridge::AST::Paragraph, Markbridge::AST::Paragraph, Markbridge::AST::Table],
      )
    end

    it "places the table between preceding and following document content" do
      doc = parser.parse("before\n{|\n| x\n|}\nafter")

      expect(doc.children.size).to eq(3)
      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[1]).to be_a(Markbridge::AST::Table)
      expect(doc.children[2]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[2].children.first.text).to eq("after")
    end

    it "does not index past end-of-input on an unclosed table" do
      # Kills `while i < lines.length` → `while i` / `while lines.length`.
      # Both mutations never terminate; on an unclosed table, the
      # index walks past end-of-input and `lines[i].strip` raises
      # NoMethodError on nil.
      expect { parser.parse("{|\n| unclosed") }.not_to raise_error
    end

    it "recognizes `{|` with leading whitespace as a table start" do
      # Kills `\A\s*\{\|` → `\A\S*\{\|` on table_start_line?. A
      # leading-indented table opener must still be detected;
      # `\S*` would require non-whitespace before `{|` and fail.
      doc = parser.parse("  {|\n| x\n|}")

      expect(doc.children.first).to be_a(Markbridge::AST::Table)
    end

    it "closes any open list before starting a table" do
      # Kills `close_open_lists` → drop / nil on the `table_start_line?`
      # branch. Without the close, the list stack stays populated
      # across the table, so a list item AFTER the table is treated
      # as a continuation of the pre-table list instead of opening a
      # fresh one.
      doc = parser.parse("* item1\n{|\n| x\n|}\n* item2")

      # Original: List(item1), Table, List(item2) — three siblings.
      # Mutation: List(item1, item2), Table — only two siblings with
      # the second item merged into the first list.
      expect(doc.children.size).to eq(3)
      expect(doc.children[0]).to be_a(Markbridge::AST::List)
      expect(doc.children[0].children.size).to eq(1)
      expect(doc.children[1]).to be_a(Markbridge::AST::Table)
      expect(doc.children[2]).to be_a(Markbridge::AST::List)
      expect(doc.children[2].children.size).to eq(1)
    end

    it "strips leading AND trailing whitespace on table lines" do
      # Kills `lines[i].strip` → `.lstrip` / `.rstrip` / no strip.
      # Indented `  | foo` must still match the `|` branch.
      table = parse_table("{|\n  | indented\n|}")

      row = table.children.first
      expect(row.children.size).to eq(1)
      expect(row.children.first.children.first.text).to eq("indented")
    end

    it "opens closing `|}` only when the line STARTS with `|}`, not ends" do
      # Kills `start_with?("|}")` → `end_with?("|}")`. A cell line
      # whose text happens to end with `|}` must be treated as cell
      # content, not as the table close.
      table = parse_table("{|\n| data ends here |}\n|}")

      expect(table.children.size).to eq(1)
      # With end_with? mutation, the trap line would break and the
      # table would close with zero rows.
      expect(table.children[0].children.size).to eq(1)
    end

    it "opens row separator `|-` only when line STARTS with `|-`, not ends" do
      # Kills `start_with?("|-")` → `end_with?("|-")`. A cell line
      # ending in `|-` text must not create a new row.
      table = parse_table("{|\n| foo\n| bar|-\n|}")

      expect(table.children.size).to eq(1)
      expect(table.children[0].children.size).to eq(2)
    end

    it "keeps consecutive `!` header lines in the SAME row absent a `|-`" do
      # Kills `ensure_table_row(table, current_row)` → `(table, nil)`
      # on the header branch. Without `|-`, consecutive headers
      # must share a row.
      table = parse_table("{|\n! A\n! B\n|}")

      expect(table.children.size).to eq(1)
      expect(table.children[0].children.size).to eq(2)
    end

    it "strips exactly ONE leading `!` before cell content" do
      # Kills `stripped[1..]` → `stripped[2..]` on the header
      # branch. With no-space input `!x`, slice(1..) is "x",
      # slice(2..) is "" (empty cell).
      table = parse_table("{|\n!x\n|}")

      row = table.children.first
      expect(row.children.size).to eq(1)
      expect(row.children.first.children.first.text).to eq("x")
    end

    it "strips exactly ONE leading `|` before cell content" do
      # Kills `stripped[1..]` → `stripped[2..]` on the data branch.
      table = parse_table("{|\n|x\n|}")

      row = table.children.first
      expect(row.children.size).to eq(1)
      expect(row.children.first.children.first.text).to eq("x")
    end

    it "splits a cell on ONLY the first attr-pipe, keeping later `|` in content" do
      # Kills the `limit - 1` → `limit` / `limit + 1` / drop-limit /
      # `< 1` / `|| true` / `|| parts.length` variants on the
      # split_outside_brackets limit check. With `limit: 2`, the
      # split must stop after one `|`, so `b | c` stays joined as
      # the cell content (not split into two "b" and "c" cells).
      table = parse_table("{|\n| a | b | c\n|}")

      row = table.children.first
      expect(row.children.size).to eq(1)
      expect(row.children.first.children.first.text).to eq("b | c")
    end

    it "keeps trailing blank cells when `||` ends the line" do
      table = parse_table("{|\n| 1 || \n|}")

      row = table.children.first
      expect(row.children.size).to eq(2)
      expect(row.children.first.children.first.text).to eq("1")
      # The trailing empty cell has no children (parse of empty content).
      expect(row.children[1].children).to be_empty
    end

    it "treats unbalanced `]]` as plain text, not a depth close" do
      # Kills `depth.positive?` → drop / `true` / `depth` (integer is
      # truthy so `depth` alone behaves like `true`). Without the
      # guard, the unbalanced `]]` would push depth to -1 and the
      # subsequent `||` would NOT split (depth != 0), collapsing the
      # row into a single cell.
      table = parse_table("{|\n| a]] || b\n|}")

      row = table.children.first
      expect(row.children.size).to eq(2)
      expect(row.children[1].children.first.text).to eq("b")
    end

    it "advances exactly 2 positions past a balanced `]]`" do
      # Kills `i += 2` → `i += 1` / `i -= 2` / `i += 0` on the `]]`
      # branch. A mis-advance leaks stray `]` / re-scans chars into
      # cell 0, producing either extra Text siblings next to the Url
      # or a wrong href. All three cases are observable on the cell
      # subtree shape.
      table = parse_table("{|\n| [[x]] || y\n|}")

      row = table.children.first
      expect(row.children.size).to eq(2)
      # Cell 0 is exactly one Url child — no stray `]`/`x` Text after.
      expect(row.children[0].children.size).to eq(1)
      url = row.children[0].children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("x")
      expect(row.children[1].children.first.text).to eq("y")
    end
  end

  describe "constructor customization" do
    it "accepts a custom inline_tag_registry" do
      registry =
        Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
          r.register("mark", :formatting, Markbridge::AST::Bold)
        end
      parser = described_class.new(inline_tag_registry: registry)
      doc = parser.parse("<mark>highlighted</mark>")

      paragraph = doc.children.first
      expect(paragraph.children.first).to be_a(Markbridge::AST::Bold)
    end

    it "accepts a block for registry customization" do
      parser = described_class.new { |r| r.register("mark", :formatting, Markbridge::AST::Bold) }
      doc = parser.parse("<mark>highlighted</mark>")

      paragraph = doc.children.first
      expect(paragraph.children.first).to be_a(Markbridge::AST::Bold)
    end
  end
end
