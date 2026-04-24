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
  end
end
