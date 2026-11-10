# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for the heading elements of Litedown, <H1> to <H6>. The
        # level is the digit in the element name.
        class HeadingHandler < BaseHandler
          # @return [AST::Heading] the heading, so the children are
          #   processed into it
          def process(element:, parent:, processor: nil)
            heading = AST::Heading.new(level: Integer(element.name.delete_prefix("H")))
            parent << heading

            heading
          end

          # @return [Class] AST::Heading
          def element_class
            AST::Heading
          end
        end
      end
    end
  end
end
