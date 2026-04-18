# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for [code]...[/code] tags.
        #
        # Preserves content as-is without parsing nested BBCode. Inherits from
        # RawHandler, which already handles the optional `lang` / option
        # attribute for language hints.
        #
        # @example
        #   # [code=python]
        #   # def hello_world
        #   #   puts "hi"
        #   # end
        #   # [/code]
        class CodeHandler < RawHandler
          def initialize
            super(AST::Code)
          end
        end
      end
    end
  end
end
