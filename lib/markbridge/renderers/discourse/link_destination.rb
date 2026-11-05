# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Writes a URL as the destination of a Markdown link or image.
      module LinkDestination
        SPECIAL = /[()\\]/
        WHITESPACE = /\s/
        ANGLE_BRACKETS = /[<>]/
        private_constant :SPECIAL, :WHITESPACE, :ANGLE_BRACKETS

        # An unbalanced parenthesis ends a CommonMark destination early, so
        # every parenthesis gets a backslash; balanced ones would be fine,
        # but the check is not worth it. A backslash is doubled, or it
        # would escape the parenthesis after it, also the one that closes
        # the destination. A destination with whitespace is wrapped in
        # <>, relevant for relative targets like MediaWiki page names
        # ("Main Page") or image files with a space in the name; a `<` or
        # `>` inside the brackets gets a backslash, or it ends them.
        #
        # The match? in front of the gsub saves the copy that gsub makes
        # also without a match: links are frequent, these characters are
        # rare.
        # @param destination [String, nil]
        # @return [String, nil] nil for nil
        def self.escape(destination)
          return nil if destination.nil?

          escaped =
            if destination.match?(SPECIAL)
              destination.gsub(SPECIAL) { |char| "\\#{char}" }
            else
              destination
            end
          return escaped unless escaped.match?(WHITESPACE)

          escaped = escaped.gsub(ANGLE_BRACKETS) { |char| "\\#{char}" } if escaped.match?(
            ANGLE_BRACKETS,
          )
          "<#{escaped}>"
        end
      end
    end
  end
end
