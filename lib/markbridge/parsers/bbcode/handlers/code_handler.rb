# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
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
