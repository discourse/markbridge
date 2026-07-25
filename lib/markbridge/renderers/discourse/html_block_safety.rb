# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Decides whether a rendered fragment is safe to splice into a
      # CommonMark HTML block (spec §4.6). Inside such a block the
      # content passes through as raw HTML; Markdown is only parsed
      # again across blank lines. Safe output is therefore: a raw HTML
      # or plain-text fragment without Markdown sigils, or a
      # +\n\n…\n\n+ wrap — a deliberate Markdown island.
      #
      # Used by the html_mode contract check that ships in
      # +markbridge/rspec+ and by this repo's own contract spec.
      module HtmlBlockSafety
        # Markdown sigils that would surface as literal text inside an
        # HTML block: emphasis (`*`, `_`, `~`) and link middles (`](`).
        MARKDOWN_SIGILS = /[*_~]|\]\(/
        private_constant :MARKDOWN_SIGILS

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
