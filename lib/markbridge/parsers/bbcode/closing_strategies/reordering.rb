# frozen_string_literal: true
module Markbridge
  module Parsers
    module BBCode
      module ClosingStrategies
        class Reordering < Base
          def handle_close(token:, context:, registry:, tokens: nil)
            closing_handler = registry[token.tag]
            return if tokens && @reconciler.try_reorder(handler: closing_handler, tokens:, context:)

            super
          end
        end
      end
    end
  end
end
