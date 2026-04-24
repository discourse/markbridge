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
    # silently skipped.
    it "skips non-TableRow children inside the table" do
      table = Markbridge::AST::Table.new
      # Interloper: a stray Paragraph shouldn't produce an extra row.
      stray = Markbridge::AST::Paragraph.new
      stray << Markbridge::AST::Text.new("stray")
      table << stray

      row = Markbridge::AST::TableRow.new
      cell = Markbridge::AST::TableCell.new
      cell << Markbridge::AST::Text.new("x")
      row << cell
      table << row

      result = tag.render(table, interface)

      expect(result).to eq("\n\n| x |\n| --- |\n\n")
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

    # Kills `r[:cells].all? { c[:header] }` → `.any?` mutations on the
    # partition guard. A row where only SOME cells are headers must
    # NOT go into <thead>; it lands in <tbody> with mixed th/td cells.
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
      expect(result).to include("<th>H</th>")
      expect(result).to include("<td>x</td>")
    end
  end
end
