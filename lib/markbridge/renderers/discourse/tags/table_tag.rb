# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering tables as Markdown pipe tables with HTML fallback
        class TableTag < Tag
          # Nodes a Markdown table cell cannot hold: they render with a
          # marker that a cell reads as text. A block of code is not here,
          # its fence lines make the cell content more than one line.
          BLOCK_NODES = [
            AST::List,
            AST::Quote,
            AST::Heading,
            AST::HorizontalRule,
            AST::Table,
            AST::Details,
            AST::Align,
            AST::Poll,
            AST::Event,
          ].freeze
          private_constant :BLOCK_NODES

          # The cells are rendered once when the place or the content of
          # the table already says that it has to be HTML. A table in a
          # table is such a case, and rendering each of them twice would
          # double the work with every level.
          def render(element, interface)
            child_context = interface.with_parent(element)

            if markdown_possible?(element, interface)
              rows_data = extract_rows(element, interface, child_context)
              return "" if rows_data.empty?
              return render_markdown(rows_data) if markdown_rows?(rows_data)
            end

            # Cells in html_mode, so inline Markdown like **bold** becomes
            # <strong>bold</strong>; CommonMark would not parse Markdown inside an HTML block.
            html_rows = extract_rows(element, interface, child_context.with_html_mode(true))
            return "" if html_rows.empty?

            html = render_html(html_rows)
            # Inside an HTML block a blank line would end the block.
            interface.html_mode? ? html : "\n\n#{html}\n\n"
          end

          private

          # Extract rendered cell data from each row
          # @return [Array<Hash>] array of {cells: [{content:, header:}], ...}
          def extract_rows(element, interface, child_context)
            element.children.filter_map do |child|
              next unless child.instance_of?(AST::TableRow)

              cells =
                child.children.filter_map do |cell|
                  next unless cell.instance_of?(AST::TableCell)

                  # Push the cell itself into the parent chain so descendants
                  # can detect they're inside a cell via has_parent?.
                  cell_context = child_context.with_parent(cell)
                  content = interface.render_children(cell, context: cell_context).strip
                  { content:, header: cell.header?, colspan: cell.colspan, rowspan: cell.rowspan }
                end

              { cells: } unless cells.empty?
            end
          end

          # What can be said without rendering a cell: a Markdown table
          # is not nested in a table and has no block in a cell.
          def markdown_possible?(element, interface)
            !interface.has_parent?(AST::Table) && !block_in_cell?(element)
          end

          # What the rendered cells say: the header row (when there is
          # one) first, every row as wide as the first, no cell on two
          # lines and no cell over several columns or rows.
          def markdown_rows?(rows_data)
            header_idx = rows_data.index { |r| r[:cells].all? { |c| c[:header] } }
            return false if header_idx&.positive?

            cell_count = rows_data.first[:cells].length
            rows_data.all? do |row|
              row[:cells].length == cell_count &&
                row[:cells].none? { |c| c[:content].include?("\n") || c[:colspan] || c[:rowspan] }
            end
          end

          def block_in_cell?(element)
            element.descendants.any? { |node| BLOCK_NODES.include?(node.class) }
          end

          # Render as Markdown pipe table. The first row is the header
          # row: markdown_compatible? lets no other header row through.
          def render_markdown(rows_data)
            header_row = rows_data.first
            data_rows = rows_data[1..]

            col_count = header_row[:cells].length
            lines = []
            lines << format_row(header_row[:cells])
            lines << "| #{(["---"] * col_count).join(" | ")} |"
            data_rows.each { |row| lines << format_row(row[:cells]) }

            "\n\n#{lines.join("\n")}\n\n"
          end

          # Format a single row as a Markdown pipe row
          def format_row(cells)
            # Pipe characters in cell content are already escaped by the markdown escaper
            "| #{cells.map { |c| c[:content] }.join(" | ")} |"
          end

          # Render as HTML table. The header rows at the top go into a
          # <thead>, the rest into a <tbody>; the rows keep their order, a
          # header row further down stays where it is.
          def render_html(rows_data)
            header_count =
              rows_data.index { |r| !r[:cells].all? { |c| c[:header] } } || rows_data.length
            lines = ["<table>"]

            if header_count.positive?
              lines << "<thead>"
              rows_data[0...header_count].each { |row| lines << html_row(row) }
              lines << "</thead>"

              if header_count < rows_data.length
                lines << "<tbody>"
                rows_data[header_count..].each { |row| lines << html_row(row) }
                lines << "</tbody>"
              end
            else
              rows_data.each { |row| lines << html_row(row) }
            end

            lines << "</table>"
            lines.join("\n")
          end

          # Discourse keeps colspan and rowspan on a cell. The values are
          # whole numbers, see AST::TableCell.
          def span_attributes(cell)
            attributes = +""
            attributes << %( colspan="#{cell[:colspan]}") if cell[:colspan]
            attributes << %( rowspan="#{cell[:rowspan]}") if cell[:rowspan]
            attributes
          end

          # Render a single HTML table row
          def html_row(row)
            cells_html =
              row[:cells].map do |cell|
                tag = cell[:header] ? "th" : "td"
                "<#{tag}#{span_attributes(cell)}>#{cell[:content]}</#{tag}>"
              end

            "<tr>#{cells_html.join}</tr>"
          end
        end
      end
    end
  end
end
