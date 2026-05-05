# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::TableTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  def build_table(rows)
    table = Markbridge::AST::Table.new
    rows.each do |row_data|
      row = Markbridge::AST::TableRow.new
      row_data.each do |cell_data|
        header = cell_data.is_a?(Hash) ? cell_data[:header] : false
        text = cell_data.is_a?(Hash) ? cell_data[:text] : cell_data
        cell = Markbridge::AST::TableCell.new(header:)
        cell << Markbridge::AST::Text.new(text)
        row << cell
      end
      table << row
    end
    table
  end

  describe "Markdown rendering" do
    it "renders a simple table with headers" do
      table = build_table([[{ text: "A", header: true }, { text: "B", header: true }], %w[1 2]])

      result = tag.render(table, interface)

      expect(result).to eq("\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n")
    end

    it "treats first row as header when no explicit headers" do
      table = build_table([%w[A B], %w[1 2]])

      result = tag.render(table, interface)

      expect(result).to eq("\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n")
    end

    it "renders multiple data rows" do
      table =
        build_table(
          [
            [{ text: "Name", header: true }, { text: "Age", header: true }],
            %w[Alice 30],
            %w[Bob 25],
          ],
        )

      result = tag.render(table, interface)

      expect(result).to include("| Name | Age |")
      expect(result).to include("| --- | --- |")
      expect(result).to include("| Alice | 30 |")
      expect(result).to include("| Bob | 25 |")
    end

    it "handles pipe characters in cell content (escaped by markdown escaper)" do
      table = build_table([[{ text: "A", header: true }, { text: "B", header: true }], %w[x|y z]])

      result = tag.render(table, interface)

      # The markdown escaper converts | to \| in text content
      expect(result).to include('x\|y')
      expect(result).to include("| z |")
    end

    it "handles empty cells" do
      table =
        build_table([[{ text: "A", header: true }, { text: "B", header: true }], ["", "data"]])

      result = tag.render(table, interface)

      expect(result).to include("|  | data |")
    end

    it "renders formatted content in cells" do
      table = Markbridge::AST::Table.new
      header_row = Markbridge::AST::TableRow.new
      h1 = Markbridge::AST::TableCell.new(header: true)
      h1 << Markbridge::AST::Text.new("Name")
      header_row << h1
      table << header_row

      data_row = Markbridge::AST::TableRow.new
      d1 = Markbridge::AST::TableCell.new
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("Alice")
      d1 << bold
      data_row << d1
      table << data_row

      result = tag.render(table, interface)

      expect(result).to include("| **Alice** |")
    end
  end

  describe "HTML fallback" do
    it "falls back to HTML when rows have different cell counts" do
      table = build_table([[{ text: "A", header: true }, { text: "B", header: true }], ["1"]])

      result = tag.render(table, interface)

      expect(result).to include("<table>")
      expect(result).to include("<th>A</th>")
      expect(result).to include("<td>1</td>")
      expect(result).to include("</table>")
    end

    it "falls back to HTML when cell content has newlines" do
      table = Markbridge::AST::Table.new
      row = Markbridge::AST::TableRow.new
      cell = Markbridge::AST::TableCell.new
      cell << Markbridge::AST::Text.new("line1\nline2")
      row << cell
      table << row

      result = tag.render(table, interface)

      expect(result).to include("<table>")
      expect(result).to include("<td>line1\nline2</td>")
    end

    it "falls back to HTML for nested tables" do
      outer_table = Markbridge::AST::Table.new
      parent_context = Markbridge::Renderers::Discourse::RenderContext.new([outer_table])
      nested_interface =
        Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, parent_context)

      table = build_table([%w[A B]])

      result = tag.render(table, nested_interface)

      expect(result).to include("<table>")
    end

    it "uses thead/tbody when header rows exist" do
      table = build_table([[{ text: "H1", header: true }, { text: "H2", header: true }], %w[a b]])

      # Force HTML fallback by making rows uneven
      extra_row = Markbridge::AST::TableRow.new
      cell = Markbridge::AST::TableCell.new
      cell << Markbridge::AST::Text.new("only one")
      extra_row << cell
      table << extra_row

      result = tag.render(table, interface)

      expect(result).to include("<thead>")
      expect(result).to include("</thead>")
      expect(result).to include("<tbody>")
      expect(result).to include("</tbody>")
    end

    it "renders bold cells as <strong> in the HTML fallback" do
      table = Markbridge::AST::Table.new
      row1 = Markbridge::AST::TableRow.new
      cell1 = Markbridge::AST::TableCell.new
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("Alice")
      cell1 << bold
      row1 << cell1
      table << row1

      # Force HTML fallback with an uneven extra row
      row2 = Markbridge::AST::TableRow.new
      cell_a = Markbridge::AST::TableCell.new
      cell_a << Markbridge::AST::Text.new("a")
      cell_b = Markbridge::AST::TableCell.new
      cell_b << Markbridge::AST::Text.new("b")
      row2 << cell_a
      row2 << cell_b
      table << row2

      result = tag.render(table, interface)

      expect(result).to include("<td><strong>Alice</strong></td>")
    end

    it "renders URL cells as <a href> in the HTML fallback" do
      table = Markbridge::AST::Table.new
      row1 = Markbridge::AST::TableRow.new
      cell1 = Markbridge::AST::TableCell.new
      url = Markbridge::AST::Url.new(href: "https://example.com")
      url << Markbridge::AST::Text.new("link")
      cell1 << url
      row1 << cell1
      table << row1

      # Force HTML fallback
      row2 = Markbridge::AST::TableRow.new
      [Markbridge::AST::TableCell.new, Markbridge::AST::TableCell.new].each do |c|
        c << Markbridge::AST::Text.new("x")
        row2 << c
      end
      table << row2

      result = tag.render(table, interface)

      expect(result).to include(%(<td><a href="https://example.com">link</a></td>))
    end

    it "renders inline code cells as <code> in the HTML fallback" do
      table = Markbridge::AST::Table.new
      row1 = Markbridge::AST::TableRow.new
      cell1 = Markbridge::AST::TableCell.new
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("x")
      cell1 << code
      row1 << cell1
      table << row1

      # Force HTML fallback
      row2 = Markbridge::AST::TableRow.new
      [Markbridge::AST::TableCell.new, Markbridge::AST::TableCell.new].each do |c|
        c << Markbridge::AST::Text.new("y")
        row2 << c
      end
      table << row2

      result = tag.render(table, interface)

      expect(result).to include("<td><code>x</code></td>")
    end

    it "HTML-escapes plain text in cells in the HTML fallback" do
      table = Markbridge::AST::Table.new
      row1 = Markbridge::AST::TableRow.new
      cell1 = Markbridge::AST::TableCell.new
      cell1 << Markbridge::AST::Text.new("a < b")
      row1 << cell1
      table << row1

      # Force HTML fallback
      row2 = Markbridge::AST::TableRow.new
      [Markbridge::AST::TableCell.new, Markbridge::AST::TableCell.new].each do |c|
        c << Markbridge::AST::Text.new("y")
        row2 << c
      end
      table << row2

      result = tag.render(table, interface)

      expect(result).to include("<td>a &lt; b</td>")
    end

    describe "block-level content in HTML fallback cells" do
      # Builds a table where the first row has a single cell containing the given
      # block child, and a second row has two cells — forcing HTML fallback via
      # uneven row widths.
      def build_uneven_table_with(child_in_first_cell)
        table = Markbridge::AST::Table.new
        row1 = Markbridge::AST::TableRow.new
        cell1 = Markbridge::AST::TableCell.new
        cell1 << child_in_first_cell
        row1 << cell1
        table << row1

        row2 = Markbridge::AST::TableRow.new
        2.times do
          c = Markbridge::AST::TableCell.new
          c << Markbridge::AST::Text.new("x")
          row2 << c
        end
        table << row2

        table
      end

      it "drops the <p> wrapper since the surrounding <td> already provides block context" do
        para = Markbridge::AST::Paragraph.new
        para << Markbridge::AST::Text.new("hello")
        table = build_uneven_table_with(para)

        result = tag.render(table, interface)
        expect(result).to include("<td>hello</td>")
      end

      it "renders unordered lists as <ul><li>" do
        list = Markbridge::AST::List.new(ordered: false)
        item = Markbridge::AST::ListItem.new
        item << Markbridge::AST::Text.new("a")
        list << item
        table = build_uneven_table_with(list)

        result = tag.render(table, interface)
        expect(result).to include("<td><ul><li>a</li></ul></td>")
      end

      it "renders ordered lists as <ol><li>" do
        list = Markbridge::AST::List.new(ordered: true)
        item = Markbridge::AST::ListItem.new
        item << Markbridge::AST::Text.new("a")
        list << item
        table = build_uneven_table_with(list)

        result = tag.render(table, interface)
        expect(result).to include("<td><ol><li>a</li></ol></td>")
      end

      it "renders headings as <h{level}>" do
        heading = Markbridge::AST::Heading.new(level: 2)
        heading << Markbridge::AST::Text.new("Title")
        table = build_uneven_table_with(heading)

        result = tag.render(table, interface)
        expect(result).to include("<td><h2>Title</h2></td>")
      end

      it "renders block code as <pre><code>" do
        code = Markbridge::AST::Code.new(language: "ruby")
        code << Markbridge::AST::Text.new("a < b\nc")
        table = build_uneven_table_with(code)

        result = tag.render(table, interface)
        expect(result).to include(
          %(<td><pre><code class="language-ruby">a &lt; b\nc</code></pre></td>),
        )
      end

      it "renders quotes as <blockquote>" do
        quote = Markbridge::AST::Quote.new(author: "John")
        quote << Markbridge::AST::Text.new("Hi")
        table = build_uneven_table_with(quote)

        result = tag.render(table, interface)
        expect(result).to include("<td><blockquote>Hi</blockquote></td>")
      end

      it "renders horizontal rules as <hr>" do
        table = build_uneven_table_with(Markbridge::AST::HorizontalRule.new)

        result = tag.render(table, interface)
        expect(result).to include("<td><hr></td>")
      end

      it "renders spoilers as <details><summary>" do
        spoiler = Markbridge::AST::Spoiler.new(title: "Reveal")
        spoiler << Markbridge::AST::Text.new("hidden")
        table = build_uneven_table_with(spoiler)

        result = tag.render(table, interface)
        expect(result).to include("<td><details><summary>Reveal</summary>hidden</details></td>")
      end
    end
  end

  describe "edge cases" do
    it "returns empty string for table with no rows" do
      table = Markbridge::AST::Table.new

      result = tag.render(table, interface)

      expect(result).to eq("")
    end

    it "handles single-cell table" do
      table = build_table([["only"]])

      result = tag.render(table, interface)

      expect(result).to include("| only |")
      expect(result).to include("| --- |")
    end

    # Kills `r[:cells].all? { c[:header] }` → `.any?`. An earlier row
    # with mixed header/data cells must NOT become header_idx; only a
    # pure all-header row qualifies. Put the mixed row first and the
    # all-header row second — correct picks row 1, `.any?` picks row 0.
    it "does not promote a mixed-header row above a true all-header row" do
      table =
        build_table(
          [
            [{ text: "M", header: true }, "data"],
            [{ text: "H1", header: true }, { text: "H2", header: true }],
            %w[d1 d2],
          ],
        )

      result = tag.render(table, interface)

      # "H1 | H2" is the header row; the mixed row falls into data.
      expect(result).to eq("\n\n| H1 | H2 |\n| --- | --- |\n| M | data |\n| d1 | d2 |\n\n")
    end

    # Kills `header_idx = nil` and `r[:cells].all? { … }` → truthy-all?
    # mutations. When a header row appears MID-TABLE (row 1 is all
    # headers, rows 0 and 2 are data), rendering must reorder so the
    # header row heads the output and the other rows become data
    # rows.
    it "places a mid-table header row at the top of the Markdown output" do
      table =
        build_table(
          [
            %w[pre1 pre2],
            [{ text: "H1", header: true }, { text: "H2", header: true }],
            %w[post1 post2],
          ],
        )

      result = tag.render(table, interface)

      # Header first, separator, then the two data rows in original order.
      expect(result).to eq("\n\n| H1 | H2 |\n| --- | --- |\n| pre1 | pre2 |\n| post1 | post2 |\n\n")
    end

    # Kills drop-AST-guard mutations on `next unless child.is_a?(AST::TableRow)`
    # and the inner `next unless cell.is_a?(AST::TableCell)` in
    # extract_rows. Non-TableRow or non-TableCell children must be
    # silently skipped — not recursively consumed.
    it "skips non-TableRow children inside the table" do
      table = Markbridge::AST::Table.new
      # Interloper: a stray Paragraph containing a TableCell. Without
      # the `next unless child.is_a?(AST::TableRow)` guard, the
      # Paragraph's inner TableCell would be harvested and rendered
      # as a phantom row. The next-drop / `unless true` / `unless child`
      # / `unless AST::TableRow` mutations all expose this by emitting
      # the extra row.
      stray = Markbridge::AST::Paragraph.new
      stray_cell = Markbridge::AST::TableCell.new
      stray_cell << Markbridge::AST::Text.new("ghost")
      stray << stray_cell
      table << stray

      row = Markbridge::AST::TableRow.new
      cell = Markbridge::AST::TableCell.new
      cell << Markbridge::AST::Text.new("real")
      row << cell
      table << row

      result = tag.render(table, interface)

      expect(result).to eq("\n\n| real |\n| --- |\n\n")
    end

    it "skips non-TableCell children inside a row" do
      table = Markbridge::AST::Table.new
      row = Markbridge::AST::TableRow.new
      # Interloper inside the row
      stray = Markbridge::AST::Text.new("ignored")
      row << stray
      cell = Markbridge::AST::TableCell.new
      cell << Markbridge::AST::Text.new("only")
      row << cell
      table << row

      result = tag.render(table, interface)

      expect(result).to eq("\n\n| only |\n| --- |\n\n")
    end

    # Kills `content.strip` → `.lstrip` / `.rstrip` / drop mutations
    # in extract_rows. Cell content with whitespace on BOTH sides must
    # end up fully stripped.
    it "strips leading AND trailing whitespace from cell content" do
      table = Markbridge::AST::Table.new
      row = Markbridge::AST::TableRow.new
      cell = Markbridge::AST::TableCell.new
      cell << Markbridge::AST::Text.new("  padded  ")
      row << cell
      table << row

      result = tag.render(table, interface)

      expect(result).to eq("\n\n| padded |\n| --- |\n\n")
    end

    # Kills the `unless cells.empty?` drop in extract_rows: rows that
    # end up with zero real cells (e.g. only interlopers) must not
    # contribute a row to rows_data.
    it "drops rows with no TableCell children entirely" do
      table = Markbridge::AST::Table.new

      empty_row = Markbridge::AST::TableRow.new
      empty_row << Markbridge::AST::Text.new("no cells")
      table << empty_row

      data_row = Markbridge::AST::TableRow.new
      data_cell = Markbridge::AST::TableCell.new
      data_cell << Markbridge::AST::Text.new("x")
      data_row << data_cell
      table << data_row

      result = tag.render(table, interface)

      # Only one row survives → rendered as both header and (no) data.
      expect(result).to eq("\n\n| x |\n| --- |\n\n")
    end

    # Kills `has_header = rows_data` / `has_header = true` mutations
    # in render_html. When no cell is flagged as header, the HTML
    # output must NOT wrap anything in <thead>/<tbody>.
    it "renders HTML without thead/tbody when no header cells are present" do
      # Force HTML fallback with different cell counts + no headers.
      table = build_table([%w[a b], %w[solo]])

      result = tag.render(table, interface)

      expect(result).to include("<table>")
      expect(result).not_to include("<thead>")
      expect(result).not_to include("<tbody>")
      expect(result).to include("<td>a</td>")
      expect(result).to include("<td>solo</td>")
    end

    # Kills mutations that swap th/td in html_row (e.g. drop the
    # ternary, `force_header: false` always, `cell[:header]` vs other).
    it "emits <th> for header cells and <td> for data cells in HTML fallback" do
      # Mixed header/data in one row forces HTML fallback (rows uneven).
      mixed_row_table =
        build_table(
          [
            [{ text: "A", header: true }, "B", { text: "C", header: true }],
            %w[a b c d], # extra cell => uneven => HTML fallback
          ],
        )

      result = tag.render(mixed_row_table, interface)

      expect(result).to include("<th>A</th>")
      expect(result).to include("<td>B</td>")
      expect(result).to include("<th>C</th>")
      expect(result).to include("<td>a</td>")
    end

    # Kills `has_header = rows_data.any? { r[:cells].any? { c[:header] } }`
    # → `.all?` mutations. A table with MIXED cells (some header, some
    # data) in a row must have `has_header = true` so the HTML output
    # wraps the all-header rows in <thead>. With `.all?`, a mixed row
    # returns false, so the table renders without <thead>/<tbody>.
    it "wraps all-header rows in <thead> even when some rows have mixed cells" do
      table =
        build_table(
          [
            [{ text: "H1", header: true }, { text: "H2", header: true }],
            [{ text: "m1", header: true }, "data1"],
            %w[d1 d2 d3], # extra cell — forces HTML fallback via uneven counts
          ],
        )

      result = tag.render(table, interface)

      expect(result).to include("<thead>")
      expect(result).to include("<tbody>")
      thead_match = result.match(%r{<thead>(.*?)</thead>}m)
      tbody_match = result.match(%r{<tbody>(.*?)</tbody>}m)
      expect(thead_match[1]).to include("<th>H1</th>")
      expect(thead_match[1]).to include("<th>H2</th>")
      expect(tbody_match[1]).to include("<th>m1</th>") # mixed row's header cell
      expect(tbody_match[1]).to include("<td>data1</td>")
      expect(tbody_match[1]).to include("<td>d1</td>")
    end

    # Kills `rows_data.any? { r -> ... }` → `.all?` on the OUTER
    # has_header probe. With `.all?`, a single data-only row would
    # flip has_header to false and the HTML path would skip
    # <thead>/<tbody>. Needs BOTH an all-header row AND a data-only
    # row (plus uneven cell counts to force HTML fallback).
    it "emits <thead>/<tbody> when at least one row has headers (not all)" do
      table =
        build_table(
          [
            [{ text: "H1", header: true }, { text: "H2", header: true }],
            %w[d1 d2],
            %w[d3 d4 d5], # uneven forces HTML fallback
          ],
        )

      result = tag.render(table, interface)

      expect(result).to include("<thead>")
      expect(result).to include("<tbody>")
    end

    # Kills `unless body_rows.empty?` → `unless false` / `unless nil`
    # / drop-unless. With an all-header table that falls into HTML
    # mode (forced by a mid-row mixed cell set that defeats the
    # markdown path), body_rows is empty and the <tbody>…</tbody>
    # pair MUST NOT appear.
    it "omits <tbody> when every row is an all-header row" do
      table =
        build_table(
          [
            [{ text: "A", header: true }, { text: "B", header: true }],
            [{ text: "C", header: true }, { text: "D", header: true }, { text: "E", header: true }], # uneven forces HTML fallback
          ],
        )

      result = tag.render(table, interface)

      expect(result).to include("<thead>")
      expect(result).not_to include("<tbody>")
      expect(result).not_to include("</tbody>")
    end

    # Kills `lines.join("\n")` → `lines.join` / `.join(nil)` /
    # `.join("")`. The HTML table output MUST have newlines between
    # `<table>`, `<thead>`, `<tr>`, etc. Without separator, the tags
    # concatenate into one long line and the output loses readability.
    it "separates HTML lines with newlines" do
      table =
        build_table(
          [
            [{ text: "H1", header: true }, { text: "H2", header: true }],
            %w[d1 d2 d3], # uneven forces HTML fallback
          ],
        )

      result = tag.render(table, interface)

      # Each HTML element should be on its own line.
      expect(result).to match(/<table>\n<thead>\n<tr>/)
      expect(result).to match(%r{</tr>\n</thead>\n<tbody>})
      expect(result).to match(%r{</tbody>\n</table>})
    end

    # Kills `r[:cells].all? { c[:header] }` → `.any?` mutations on the
    # partition guard. A row where only SOME cells are headers must
    # NOT go into <thead>; it lands in <tbody> with mixed th/td cells.
    # Also kills the INNER `r[:cells].any? { c[:header] }` → `.all?`
    # on the has_header probe — with the mutation, a mixed row
    # (one header, one data) returns false for `.all?`, so has_header
    # flips to false and <tbody> disappears.
    it "routes a mixed-header row to <tbody>, not <thead>" do
      table =
        build_table(
          [
            [{ text: "H", header: true }, "x"], # mixed — not a header-only row
            %w[d1 d2],
            %w[d3 d4 d5], # uneven — forces HTML fallback
          ],
        )

      result = tag.render(table, interface)

      # No <thead> because no row has all cells as headers.
      expect(result).not_to include("<thead>")
      # <tbody> must still appear — the inner-any-vs-all mutation
      # would flip has_header to false and drop <tbody> entirely.
      expect(result).to include("<tbody>")
      expect(result).to include("<th>H</th>")
      expect(result).to include("<td>x</td>")
    end
  end

  describe "emission scoping" do
    let(:emitting_bold) do
      Class.new(Markbridge::Renderers::Discourse::Tag) do
        def render(_element, interface)
          interface.emit(:probe, true)
          "x"
        end
      end
    end

    def cell_table(rows)
      table = Markbridge::AST::Table.new
      rows.each do |cells|
        row = Markbridge::AST::TableRow.new
        cells.each do |cell_text|
          tc = Markbridge::AST::TableCell.new(header: false)
          bold = Markbridge::AST::Bold.new
          bold << Markbridge::AST::Text.new(cell_text)
          tc << bold
          row << tc
        end
        table << row
      end
      table
    end

    it "does not double-emit when the table is markdown-compatible (single pass)" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(Markbridge::AST::Bold, emitting_bold.new)
      r = Markbridge::Renderers::Discourse::Renderer.new(tag_library: library)

      r.render(Markbridge::AST::Document.new << cell_table([%w[a b], %w[c d]]))

      expect(r.emissions[:probe].size).to eq(4)
    end

    it "discards emissions from the throwaway Markdown pass when falling back to HTML" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(Markbridge::AST::Bold, emitting_bold.new)
      r = Markbridge::Renderers::Discourse::Renderer.new(tag_library: library)

      # Uneven rows: Markdown pass discarded, cells re-rendered in
      # html_mode. The 3 emissions from the discarded pass must be
      # rolled back so only the 3 HTML-pass emissions remain.
      r.render(Markbridge::AST::Document.new << cell_table([%w[a b], %w[c]]))

      expect(r.emissions[:probe].size).to eq(3)
    end
  end
end
