# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module ClosingStrategies
        # Encapsulates logic for reconciling mismatched closing tags
        class TagReconciler
          MAX_AUTO_CLOSE_DEPTH = 5

          def initialize(registry:)
            @registry = registry
          end

          # Attempt to auto-close tags to match a closing tag
          #
          # @param handler [BaseHandler] the handler for the closing tag
          # @param context [ParserState]
          # @return [Boolean] true if successful, false if auto-close not possible
          def try_auto_close(handler:, context:)
            count = auto_close_count(handler, context)
            return false if count.nil?

            count.times { context.pop }
            context.auto_close!(count)

            true
          end

          # Attempt to close the target tag and reopen any intervening
          # auto-closeable tags so subsequent content continues in the same
          # formatting context. Used when closing tags are not adjacent
          # (e.g. "[b][i]x[/b] more[/i]").
          #
          # Reopening only makes sense when there is upcoming content that
          # would benefit from the reopened context. If the next token is a
          # closing tag (or nothing), plain auto-close is correct.
          #
          # @param handler [BaseHandler] the handler for the closing tag
          # @param context [ParserState]
          # @param tokens [Object, nil] the token stream (used to check that content follows)
          # @return [Boolean] true if successful, false otherwise
          def try_reopen(handler:, context:, tokens:)
            case tokens&.peek
            when TextToken, TagStartToken
              nil # content follows -> reopening is justified
            else
              return false
            end

            match_depth = find_matching_handler_depth(handler, context)
            return false if match_depth.nil? || match_depth.zero?
            return false unless all_auto_closeable?(context, match_depth)

            intervening = context.elements_from_current(match_depth - 1).map(&:class)

            count = match_depth + 1
            count.times { context.pop }
            context.auto_close!(count)

            intervening.reverse_each { |klass| context.push(klass.new) }

            true
          end

          # Attempt to reorder closing tags
          #
          # @param handler [BaseHandler] the handler for the closing tag
          # @param tokens [Object] the token stream
          # @param context [ParserState]
          # @return [Boolean] true if successful, false otherwise
          def try_reorder(handler:, tokens:, context:)
            match_depth = find_matching_handler_depth(handler, context)
            opening_handlers = collect_auto_closeable_handlers(context, match_depth)

            closing_handlers = [handler, *peek_closing_handlers(tokens, opening_handlers.size - 1)]
            unless opening_handlers.sort_by(&:object_id) == closing_handlers.sort_by(&:object_id)
              return false
            end

            # Consume the extra closing tags. We've already verified via
            # peek_closing_handlers that the next opening_handlers.size - 1
            # tokens are TagEndTokens with handlers we accept.
            (opening_handlers.size - 1).times { tokens.next }

            opening_handlers.each { context.pop }
            context.auto_close!(opening_handlers.size)

            true
          end

          private

          # Number of stack elements to pop in order to close `handler`, or nil
          # when the handler is not on the stack within MAX_AUTO_CLOSE_DEPTH or
          # any intervening element is not auto-closeable.
          def auto_close_count(handler, context)
            context
              .elements_from_current(MAX_AUTO_CLOSE_DEPTH - 1)
              .each_with_index do |element, depth|
                return nil unless @registry.auto_closeable?(element.class)
                return depth + 1 if @registry.handler_for_element(element) == handler
              end

            nil
          end

          def find_matching_handler_depth(handler, context)
            context
              .elements_from_current(MAX_AUTO_CLOSE_DEPTH - 1)
              .each_with_index do |element, depth|
                return depth if @registry.handler_for_element(element) == handler
              end

            nil
          end

          def all_auto_closeable?(context, target_depth)
            context
              .elements_from_current(target_depth)
              .all? { |element| @registry.auto_closeable?(element.class) }
          end

          # Caller must have verified all_auto_closeable?(context, target_depth) first.
          def collect_auto_closeable_handlers(context, target_depth)
            context
              .elements_from_current(target_depth)
              .map { |element| @registry.handler_for_element(element) }
          end

          def peek_closing_handlers(tokens, max_count)
            tokens
              .peek_ahead(max_count)
              .take_while { |token| token.instance_of?(TagEndToken) }
              .map { |token| @registry[token.tag] }
          end
        end
      end
    end
  end
end
