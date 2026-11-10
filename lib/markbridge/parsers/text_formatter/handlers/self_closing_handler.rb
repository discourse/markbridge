# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for an element without content, like <HR>. Appends an
        # instance of +element_class+ to +parent+ and returns nil, so the
        # parser does not process the children: they are only the markup
        # s9e keeps for unparsing.
        class SelfClosingHandler < BaseHandler
          # @param element_class [Class] the AST node class to instantiate
          def initialize(element_class)
            @element_class = element_class
          end

          # @return [nil]
          def process(element:, parent:, processor: nil)
            parent << @element_class.new
            nil
          end

          attr_reader :element_class
        end
      end
    end
  end
end
