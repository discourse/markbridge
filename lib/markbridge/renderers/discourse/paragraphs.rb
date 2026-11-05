# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Inline markup like `**` or `[u]` can't span a blank line: the blank
      # line ends the paragraph and the markers stay visible as text. Forums
      # allow `[b]` around several paragraphs, so the markup has to be
      # closed before every blank line and opened again after it.
      #
      # The serializer does that for emphasis, strikethrough and underline.
      # A custom tag that writes its own markers into a String can use
      # {.wrap} or {.map} for the same.
      module Paragraphs
        # One or more blank lines.
        BREAK = /\n[[:blank:]]*\n/
        # The same with all the blank lines of a run, captured so that
        # split keeps them.
        SPLIT = /(\n[[:blank:]]*\n(?:[[:blank:]]*\n)*)/
        # Whitespace at the start and at the end, and what is between.
        EDGES = /\A([[:space:]]*)(.*?)([[:space:]]*)\z/m
        private_constant :BREAK, :SPLIT, :EDGES

        # Whether +content+ has a blank line that markup would have to be
        # closed and opened again around. A blank line inside a code fence
        # belongs to the code, so content with a fence is one paragraph.
        #
        # @param content [String]
        # @return [Boolean]
        def self.many?(content)
          content.match?(BREAK) && !content.include?("```") && !content.include?("~~~")
        end

        # Yields each paragraph of +content+ on its own and joins the
        # results with the original blank lines. Content without a blank
        # line is yielded as a whole. A blank line at the start or at the
        # end is kept, and the empty String in front of a blank line at
        # the start is yielded like a paragraph.
        #
        # @param content [String]
        # @yieldparam paragraph [String] content without a blank line
        # @yieldparam first [Boolean] whether it is the first paragraph
        # @yieldparam last [Boolean] whether it is the last paragraph
        # @yieldreturn [String] the wrapped paragraph
        # @return [String]
        # @example
        #   Paragraphs.map("a\n\nb") { |paragraph| "**#{paragraph}**" }
        #   # => "**a**\n\n**b**"
        def self.map(content)
          return yield(content, true, true) unless many?(content)

          parts = content.split(SPLIT)
          # Even indexes are paragraphs, odd ones the blank lines between.
          last = parts.size - 1
          last -= 1 if last.odd?
          parts
            .each_with_index
            .map { |part, index| index.odd? ? part : yield(part, index.zero?, index == last) }
            .join
        end

        # Puts +open+ and +close+ around every paragraph of +content+.
        # Whitespace at the edges of a paragraph stays outside, and a
        # paragraph with only whitespace stays as it is.
        #
        # @param content [String]
        # @param open [String]
        # @param close [String]
        # @return [String]
        # @example
        #   Paragraphs.wrap("a \n\nb", "[color=red]", "[/color]")
        #   # => "[color=red]a[/color] \n\n[color=red]b[/color]"
        def self.wrap(content, open, close)
          map(content) do |paragraph|
            lead, core, trail = paragraph.match(EDGES).captures
            core.empty? ? paragraph : "#{lead}#{open}#{core}#{close}#{trail}"
          end
        end
      end
    end
  end
end
