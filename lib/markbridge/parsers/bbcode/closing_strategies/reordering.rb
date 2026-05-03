# frozen_string_literal: true
module Markbridge
  module Parsers
    module BBCode
      module ClosingStrategies
        class Reordering < Base
          def handle_close(token:, context:, registry:, tokens: nil)
            closing_handler = registry[token.tag]

            # Fast path: when the current element matches the closing tag,
            # pop and return. try_reorder/try_reopen are reconciliation
            # strategies that only make sense when the close is mismatched;
            # running them eagerly here costs a full elements_from_current
            # walk plus two sort_by/compare passes on every close token,
            # which dominates runtime for well-formed input.
            if registry.handler_for_element(context.current) == closing_handler
              context.pop
              return
            end

            return if tokens && @reconciler.try_reorder(handler: closing_handler, tokens:, context:)
            return if @reconciler.try_reopen(handler: closing_handler, context:, tokens:)

            super
          end
        end
      end
    end
  end
end
