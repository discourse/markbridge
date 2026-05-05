# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering tables as Markdown pipe tables with HTML fallback
        class TableTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)

            # Render cells provisionally in Markdown mode. Emissions
            # from this pass are kept only when the Markdown form
            # survives; if the table is markdown-incompatible we
            # discard the pass and re-render in html_mode.
            markdown =
              interface.with_provisional_emissions do |controller|
                rows_data = extract_rows(element, interface, child_context)
                next nil if rows_data.empty? || !markdown_compatible?(rows_data, interface)

                controller.commit
                render_markdown(rows_data)
              end

            return markdown if markdown
            return "" if empty_table?(element)

            # Re-render cells in html_mode so inline Markdown like **bold** becomes
            # <strong>bold</strong>; CommonMark would not parse Markdown inside an HTML block.
            html_rows = extract_rows(element, interface, child_context.with_html_mode(true))
            render_html(html_rows)
          end

          private

          def empty_table?(element)
            element.children.none? { |c| c.instance_of?(AST::TableRow) }
          end

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
                  { content:, header: cell.header? }
                end

              { cells: } unless cells.empty?
            end
          end

          # Check if the table can be rendered as Markdown
          def markdown_compatible?(rows_data, interface)
            return false if interface.has_parent?(AST::Table)

            cell_count = rows_data.first[:cells].length
            rows_data.all? do |row|
              row[:cells].length == cell_count &&
                row[:cells].none? { |c| c[:content].include?("\n") }
            end
          end

          # Render as Markdown pipe table
          def render_markdown(rows_data)
            header_idx = rows_data.index { |r| r[:cells].all? { |c| c[:header] } }
            header_row = header_idx ? rows_data[header_idx] : rows_data.first
            data_rows =
              (
                if header_idx
                  rows_data[0...header_idx] + rows_data[(header_idx + 1)..]
                else
                  rows_data[1..]
                end
              )

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

          # Render as HTML table
          def render_html(rows_data)
            has_header = rows_data.any? { |r| r[:cells].any? { |c| c[:header] } }
            lines = ["<table>"]

            if has_header
              header_rows, body_rows = rows_data.partition { |r| r[:cells].all? { |c| c[:header] } }

              unless header_rows.empty?
                lines << "<thead>"
                header_rows.each { |row| lines << html_row(row) }
                lines << "</thead>"
              end

              unless body_rows.empty?
                lines << "<tbody>"
                body_rows.each { |row| lines << html_row(row) }
                lines << "</tbody>"
              end
            else
              rows_data.each { |row| lines << html_row(row) }
            end

            lines << "</table>"
            "\n\n#{lines.join("\n")}\n\n"
          end

          # Render a single HTML table row
          def html_row(row)
            cells_html =
              row[:cells].map do |cell|
                tag = cell[:header] ? "th" : "td"
                "<#{tag}>#{cell[:content]}</#{tag}>"
              end

            "<tr>#{cells_html.join}</tr>"
          end
        end
      end
    end
  end
end
