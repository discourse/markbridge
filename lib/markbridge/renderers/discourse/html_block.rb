# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # The one place that knows how CommonMark HTML blocks (spec §4.6)
      # and Markdown meet in the rendered output.
      #
      # Inside an HTML block the content passes through as raw HTML.
      # Markdown is parsed again only across blank lines. A tag that
      # renders into such a block therefore picks one of two forms:
      #
      # 1. raw HTML — an HTML equivalent of the tag's Markdown, spliced
      #    into the block as it is, with no blank line in it;
      # 2. a Markdown island — the tag's normal Markdown surrounded by
      #    blank lines, which end the block, and a line that opens it
      #    again after them:
      #
      #        <div align="center">
      #
      #        [a link](https://example.com)
      #
      #        </div>
      #
      # Inside an HTML block the island is always in a `<div>`
      # (.enclosed_island, which a tag reaches through
      # RenderingInterface#markdown_island). After a bare island the rest
      # of the cell would be Markdown too.
      module HtmlBlock
        # Tag names that start a type 6 HTML block when a line begins
        # with `<name` or `</name` followed by a space, a tab, `>`, `/>`
        # or the end of the line.
        BLOCK_TAGS = %w[
          address
          article
          aside
          base
          basefont
          blockquote
          body
          caption
          center
          col
          colgroup
          dd
          details
          dialog
          dir
          div
          dl
          dt
          fieldset
          figcaption
          figure
          footer
          form
          frame
          frameset
          h1
          h2
          h3
          h4
          h5
          h6
          head
          header
          hr
          html
          iframe
          legend
          li
          link
          main
          menu
          menuitem
          nav
          noframes
          ol
          optgroup
          option
          p
          param
          search
          section
          summary
          table
          tbody
          td
          tfoot
          th
          thead
          title
          tr
          track
          ul
        ].freeze

        # The spec allows up to three leading spaces. We match any amount
        # of leading whitespace instead, because the lines this runs on
        # are item content that the list builder has not indented yet.
        OPENER = %r{\A[ \t]*</?(?:#{Regexp.union(BLOCK_TAGS).source})(?:[ \t>]|/>|\z)}i

        # The newline in front of a line that holds nothing but spaces and
        # tabs: with the line it makes a blank line.
        BLANK_LINE_NEWLINE = /\n(?=[ \t]*\n)/

        # Markdown sigils that would surface as literal text inside an
        # HTML block: emphasis (`*`, `_`, `~`) and link middles (`](`).
        MARKDOWN_SIGILS = /[*_~]|\]\(/

        # Blank lines at the start or at the end of a fragment. The first
        # content line keeps its own indentation, e.g. a nested `  - a`.
        BLANK_EDGES = /\A(?:[ \t]*\n)+|(?:\n[ \t]*)+\z/

        private_constant :BLOCK_TAGS, :OPENER, :BLANK_LINE_NEWLINE, :MARKDOWN_SIGILS, :BLANK_EDGES

        # Whether +line+ starts an HTML block. A closing tag such as
        # `</div>` starts one too. The block runs until the next blank
        # line.
        # @param line [String]
        # @return [Boolean]
        def self.opens?(line)
          OPENER.match?(line)
        end

        # Wrap Markdown so that CommonMark parses it even inside an HTML
        # block. Blank lines that the fragment already has at its edges
        # are folded into the wrap.
        # @param markdown [String]
        # @return [String]
        # @example
        #   HtmlBlock.island("- a\n") # => "\n\n- a\n\n"
        def self.island(markdown)
          "\n\n#{markdown.gsub(BLANK_EDGES, "")}\n\n"
        end

        # An island for the inside of an HTML block, in a `<div>`. After
        # a bare island what follows on the same lines is Markdown until
        # a line opens an HTML block again, so text after it in a table
        # cell would get Markdown meaning; the `</div>` line opens the
        # block again. A `div` is a block in the HTML as well, so the
        # island shows as a paragraph of its own, like a bare island
        # does.
        # @param markdown [String]
        # @return [String]
        # @example
        #   HtmlBlock.enclosed_island("![a](b)") # => "<div>\n\n![a](b)\n\n</div>"
        def self.enclosed_island(markdown)
          "<div>#{island(markdown)}</div>"
        end

        # Text for the inside of an HTML block, with no blank line in it:
        # a blank line ends the block, and what follows is Markdown
        # again. The newline that would start a blank line is written as
        # the entity, which the HTML parser reads back as a newline.
        # @param text [String] text or HTML, already escaped
        # @return [String]
        # @example
        #   HtmlBlock.without_blank_lines("a\n\nb") # => "a&#10;\nb"
        def self.without_blank_lines(text)
          return text unless text.include?("\n")

          text.gsub(BLANK_LINE_NEWLINE, "&#10;")
        end

        # Whether a fragment can be spliced into an HTML block: an island
        # in a `<div>`, or raw HTML or plain text without Markdown sigils
        # and without a blank line. A blank line anywhere else ends the
        # block, and what follows it is Markdown until a line opens a
        # block again; a bare island, `\n\n…\n\n`, is not accepted for
        # that reason.
        #
        # Used by the html_mode contract check that ships in
        # +markbridge/rspec+ and by this repo's own contract spec.
        # @param output [String] a tag's html_mode render result
        # @return [Boolean]
        def self.safe?(output)
          return true if output.start_with?("<div>\n\n") && output.end_with?("\n\n</div>")

          !output.match?(MARKDOWN_SIGILS) && !output.match?(BLANK_LINE_NEWLINE)
        end
      end
    end
  end
end
