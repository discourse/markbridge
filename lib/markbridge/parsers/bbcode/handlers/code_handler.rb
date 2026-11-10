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

          # A line break right after [code] or [pre] is where the author
          # started the code on a line of its own. It is not a first, empty
          # line of the code.
          def create_element(token:, content:)
            block = BLOCK_TAGS.include?(token.tag)
            content = content.delete_prefix("\n") if block
            element =
              AST::Code.new(
                language: token.attrs[:lang] || token.attrs[:option],
                block: (true if block),
              )
            element << AST::Text.new(content) unless content.empty?
            element
          end
        end
      end
    end
  end
end
