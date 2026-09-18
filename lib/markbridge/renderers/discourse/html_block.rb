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
      #    into the block as it is;
      # 2. a Markdown island — the tag's normal Markdown surrounded by
      #    blank lines, which end the block and start it again:
      #
      #        <div align="center">
      #
      #        [a link](https://example.com)
      #
      #        </div>
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

        # Markdown sigils that would surface as literal text inside an
        # HTML block: emphasis (`*`, `_`, `~`) and link middles (`](`).
        MARKDOWN_SIGILS = /[*_~]|\]\(/

        # Blank lines at the start or at the end of a fragment. The first
        # content line keeps its own indentation, e.g. a nested `  - a`.
        BLANK_EDGES = /\A(?:[ \t]*\n)+|(?:\n[ \t]*)+\z/

        private_constant :BLOCK_TAGS, :OPENER, :MARKDOWN_SIGILS, :BLANK_EDGES

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

        # Whether a fragment can be spliced into an HTML block: raw HTML
        # or plain text without Markdown sigils, or an island.
        #
        # Used by the html_mode contract check that ships in
        # +markbridge/rspec+ and by this repo's own contract spec.
        # @param output [String] a tag's html_mode render result
        # @return [Boolean]
        def self.safe?(output)
          return true if output.start_with?("\n\n") && output.end_with?("\n\n")

          !output.match?(MARKDOWN_SIGILS)
        end
      end
    end
  end
end
