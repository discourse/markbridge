# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        class BaseHandler
          # Default opening behavior: create element and push to context
          # Subclasses should override this method
          # @param token [TagStartToken]
          # @param context [ParserState]
          # @param registry [HandlerRegistry]
          # @param tokens [Enumerator, nil]
          # @return [void]
          def on_open(token:, context:, registry:, tokens: nil)
            # Default: do nothing, subclasses override
          end

          # Default closing behavior: pop matching element from stack
          # Subclasses can override or call super for custom behavior
          # @param token [TagEndToken]
          # @param context [ParserState]
          # @param registry [HandlerRegistry]
          # @param tokens [PeekableEnumerator, nil]
          # @return [void]
          def on_close(token:, context:, registry:, tokens: nil)
            registry.close_element(token:, context:, tokens:)
          end

          # Whether elements created by this handler can be auto-closed
          # @return [Boolean]
          def auto_closeable?
            false
          end

          # The element class created by this handler
          # Subclasses must expose this via attr_reader :element_class
          # @return [Class]
          attr_reader :element_class
        end
      end
    end
  end
end
