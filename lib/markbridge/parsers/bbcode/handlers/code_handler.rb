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
          # Tags that mean a code block by definition; [tt] is inline
          # teletype and leaves the decision to the renderer.
          BLOCK_TAGS = %w[code pre].freeze
          private_constant :BLOCK_TAGS

          def initialize
            super(AST::Code)
          end

          private

          def create_element(token:, content:)
            element =
              AST::Code.new(
                language: token.attrs[:lang] || token.attrs[:option],
                block: (true if BLOCK_TAGS.include?(token.tag)),
              )
            element << AST::Text.new(content) unless content.empty?
            element
          end
        end
      end
    end
  end
end
