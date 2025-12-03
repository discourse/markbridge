# frozen_string_literal: true
module Markbridge
  module Parsers
    module BBCode
      module ClosingStrategies
        class Reordering < Base
          private

          def try_reorder(context:, tokens:, closing_handler:)
            return false unless tokens
            @reconciler.try_reorder(handler: closing_handler, tokens:, context:)
          end
        end
      end
    end
  end
end
