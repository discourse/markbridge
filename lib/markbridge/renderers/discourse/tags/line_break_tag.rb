# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Line breaks: a hard break token, which the serializer writes as a
        # newline, as <br> on a line that holds nothing else (a newline
        # there would be a blank line, which ends the paragraph and makes
        # a list loose), and as <br> in an HTML block. A heading is one
        # line, so a break in a heading is <br> as well.
        class LineBreakTag < Tag
          HARD_BREAK = [Inline::Tokens.hard_break].freeze
          private_constant :HARD_BREAK

          def render(_element, interface)
            interface.has_parent?(AST::Heading) ? "<br>" : HARD_BREAK
          end
        end
      end
    end
  end
end
