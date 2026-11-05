# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Inline
        # The tokens a tag gives the {Serializer} instead of finished
        # Markdown. A token is a plain Array with its kind first, so
        # building one costs a single allocation, or none for the tokens
        # that carry no value; the constructors here are the only place
        # that knows the layout. Finished Markdown is a token too: a plain
        # String among the tokens is written as it is, and the serializer
        # joins it with its neighbors by its first and last character.
        module Tokens
          # Text the serializer escapes.
          TEXT = :text
          # Finished Markdown from a tag, written as it is. Such a token is
          # the String itself, see {.raw}.
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
          # Text that a later step replaces, with what will most likely
          # take its place, see {.placeholder}.
          PLACEHOLDER = :placeholder

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
          # @return [String] the Markdown itself
          def self.raw(markdown)
            markdown
          end

          OPEN_TOKENS = DELIMITERS.to_h { |delimiter| [delimiter, [OPEN, delimiter].freeze] }.freeze
          CLOSE_TOKENS =
            DELIMITERS.to_h { |delimiter| [delimiter, [CLOSE, delimiter].freeze] }.freeze
          private_constant :OPEN_TOKENS, :CLOSE_TOKENS

          # @param delimiter [Symbol] one of {DELIMITERS}
          # @return [Array] the same frozen token on every call
          def self.open(delimiter)
            OPEN_TOKENS.fetch(delimiter)
          end

          # @param delimiter [Symbol] one of {DELIMITERS}
          # @return [Array] the same frozen token on every call
          def self.close(delimiter)
            CLOSE_TOKENS.fetch(delimiter)
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

          # Text for a later step to replace, like `[link|17]` that an
          # importer swaps for the real URL. The serializer writes +text+
          # as it is, but joins it with its neighbors as if +like+ stood
          # there: whether a marker next to it needs `<!---->`, whether a
          # bare URL in front of it can stay bare, whether a `!` in front
          # of it needs a backslash. In an HTML block +text+ is written as
          # it is. See "Placeholders" in the Extending guide.
          #
          # @param text [String] the placeholder, written as it is
          # @param like [String] Markdown that will most likely replace
          #   it, such as `https://example.com/t/17` or `@alice`; its first
          #   and its last character decide the joins
          # @return [Array]
          # @raise [ArgumentError] when +like+ is no String or is empty
          # @example
          #   Tokens.placeholder("[link|17]", like: "https://example.com/t/17")
          def self.placeholder(text, like:)
            unless like.instance_of?(String) && !like.empty?
              raise ArgumentError, "like: must be a non-empty String, got #{like.inspect}"
            end

            [PLACEHOLDER, text, like]
          end

          # Whether the tokens put something on the page: text or Markdown
          # with something other than whitespace in it, code, a link, a
          # bare URL, an image or a placeholder whose +like+ is visible.
          # Delimiters and hard breaks alone do not.
          #
          # @param tokens [Array<Array>]
          # @return [Boolean]
          def self.visible?(tokens)
            tokens.any? do |token|
              next Joins.visible?(token) if token.instance_of?(String)

              case token.first
              when TEXT, HTML
                Joins.visible?(token.fetch(1))
              when PLACEHOLDER
                Joins.visible?(token.fetch(2))
              when CODE
                !token.fetch(1).empty?
              when LINK_OPEN, BARE_URL, IMAGE
                true
              end
            end
          end
        end
      end
    end
  end
end
