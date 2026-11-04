# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Inline
        # The tokens a tag gives the {Serializer} instead of finished
        # Markdown. A token is a plain Array with its kind first, so
        # building one costs a single allocation; the constructors here
        # are the only place that knows the layout.
        #
        # A tag that still returns a String is not wrong: the renderer
        # wraps the String in a {.raw} token, and the serializer joins it
        # with its neighbors by its first and last character.
        module Tokens
          # Text the serializer escapes.
          TEXT = :text
          # Finished Markdown from a tag, written as it is.
          RAW = :raw
          # The start of a delimiter pair, see {DELIMITERS}.
          OPEN = :open
          # The end of a delimiter pair.
          CLOSE = :close
          # A code span. The serializer picks the backtick run.
          CODE = :code
          # The start of a link with the destination.
          LINK_OPEN = :link_open
          # The end of a link.
          LINK_CLOSE = :link_close
          # A link whose text is its href. The serializer decides from the
          # neighbors whether it can stay bare.
          BARE_URL = :bare_url
          # An image.
          IMAGE = :image
          # A hard line break.
          HARD_BREAK = :hard_break
          # Raw HTML that stays inline HTML in Markdown.
          HTML = :html

          # How a text token is escaped: as Markdown text, as the label of
          # a link (also `]`), or not at all (inside a code span).
          ESCAPE = :escape
          LABEL = :label
          VERBATIM = :verbatim

          # The delimiter pairs {.open} and {.close} name.
          DELIMITERS = %i[strong em s u].freeze

          # @param string [String]
          # @param mode [Symbol] {ESCAPE}, {LABEL} or {VERBATIM}
          # @return [Array]
          def self.text(string, mode = ESCAPE)
            [TEXT, string, mode]
          end

          # @param markdown [String]
          # @return [Array]
          def self.raw(markdown)
            [RAW, markdown]
          end

          # @param delimiter [Symbol] one of {DELIMITERS}
          # @return [Array]
          def self.open(delimiter)
            [OPEN, delimiter]
          end

          # @param delimiter [Symbol] one of {DELIMITERS}
          # @return [Array]
          def self.close(delimiter)
            [CLOSE, delimiter]
          end

          # @param content [String] the code, not escaped
          # @return [Array]
          def self.code(content)
            [CODE, content]
          end

          # @param destination [String] the href, not escaped
          # @return [Array]
          def self.link_open(destination)
            [LINK_OPEN, destination]
          end

          LINK_CLOSE_TOKEN = [LINK_CLOSE].freeze
          private_constant :LINK_CLOSE_TOKEN

          # @return [Array]
          def self.link_close
            LINK_CLOSE_TOKEN
          end

          # @param href [String]
          # @return [Array]
          def self.bare_url(href)
            [BARE_URL, href]
          end

          # @param src [String]
          # @param alt [String, nil]
          # @param width [Integer, nil]
          # @param height [Integer, nil]
          # @return [Array]
          def self.image(src:, alt: nil, width: nil, height: nil)
            [IMAGE, src, alt, width, height]
          end

          HARD_BREAK_TOKEN = [HARD_BREAK].freeze
          private_constant :HARD_BREAK_TOKEN

          # @return [Array]
          def self.hard_break
            HARD_BREAK_TOKEN
          end

          # @param string [String] HTML, already escaped
          # @return [Array]
          def self.html(string)
            [HTML, string]
          end
        end
      end
    end
  end
end
