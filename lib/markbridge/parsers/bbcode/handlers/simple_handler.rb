# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Simple formatting handlers that just push an element
        class SimpleHandler < BaseHandler
          def initialize(element_class, auto_closeable: false)
            @element_class = element_class
            @auto_closeable = auto_closeable
          end

          def on_open(token:, context:, registry:, tokens: nil)
            element = @element_class.new
            context.push(element, token:)
          end

          def auto_closeable?
            @auto_closeable
          end

          attr_reader :element_class
        end
      end
    end
  end
end
