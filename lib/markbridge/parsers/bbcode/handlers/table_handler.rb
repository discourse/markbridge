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

          def on_close(token:, context:, registry:, tokens: nil)
            # Auto-close open cell before closing row
            context.pop if context.current.instance_of?(AST::TableCell)
            # Auto-close open row before closing table
            context.pop if context.current.instance_of?(AST::TableRow)

            super
          end

          attr_reader :element_class
        end
      end
    end
  end
end
