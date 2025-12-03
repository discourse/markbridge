# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for [code]...[/code] tags
        #
        # Preserves content as-is without parsing nested BBCode
        # Inherits from RawHandler using AST::Code element
        #
        # Example:
        # [code=python]
        # def hello_world():
        #   print("Hello, world!")
        # [/code]
        class CodeHandler < RawHandler
          def initialize
            super(AST::Code)
          end
        end
      end
    end
  end
end
