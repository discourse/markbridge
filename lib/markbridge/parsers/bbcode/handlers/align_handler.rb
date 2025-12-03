# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for ALIGN tags (center, left, right, justify)
        # Creates a generic Align element with the appropriate alignment
        class AlignHandler < BaseHandler
          def initialize(alignment)
            @alignment = alignment
            @element_class = AST::Align
          end

          def on_open(token:, context:, registry:, tokens: nil)
            element = AST::Align.new(alignment: @alignment)
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
