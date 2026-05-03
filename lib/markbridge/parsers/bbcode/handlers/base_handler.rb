# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        class BaseHandler
          # @param token [TagStartToken]
          # @param context [ParserState]
          # @param registry [HandlerRegistry]
          # @param tokens [Enumerator, nil]
          def on_open(token:, context:, registry:, tokens: nil)
          end

          # @param token [TagEndToken]
          # @param context [ParserState]
          # @param registry [HandlerRegistry]
          # @param tokens [PeekableEnumerator, nil]
          def on_close(token:, context:, registry:, tokens: nil)
            registry.close_element(token:, context:, tokens:)
          end

          # @return [Boolean]
          def auto_closeable?
            false
          end

          # @return [Class]
          attr_reader :element_class
        end
      end
    end
  end
end
