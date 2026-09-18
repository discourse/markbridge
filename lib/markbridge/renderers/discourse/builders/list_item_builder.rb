# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Builders
        # Formats one list item: the marker goes in front of the first
        # line, every other line moves right by the width of the marker.
        # The content is indented as one unit, so nested lists, code
        # fences and HTML blocks inside it keep the shape they already
        # have. Blank lines stay blank; the postprocessor clears
        # whitespace-only lines anyway.
        class ListItemBuilder
          # @param content [String] the item content
          # @param marker [String] the list marker ("- " or "1. ")
          # @return [String]
          # @example
          #   builder.build("a\nb", marker: "- ") # => "- a\n  b\n"
          def build(content, marker:)
            lines = content.split("\n")
            first_line = "#{marker}#{lines.first}"
            return "#{first_line}\n" if lines.size < 2

            indent = " " * marker.length
            # An empty line maps to nil, and join turns that back into
            # an empty line. Indenting it instead would leave a line
            # with nothing but spaces on it.
            rest = lines[1..].map { |line| "#{indent}#{line}" unless line.empty? }
            "#{([first_line] + rest).join("\n")}\n"
          end
        end
      end
    end
  end
end
