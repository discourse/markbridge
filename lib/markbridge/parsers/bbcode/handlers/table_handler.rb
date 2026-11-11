# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for table tags
        class TableHandler < BaseHandler
          def initialize
            @element_class = AST::Table
          end

          def on_open(token:, context:, registry:, tokens: nil)
            element = AST::Table.new
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
