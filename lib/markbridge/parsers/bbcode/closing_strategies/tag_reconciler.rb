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
            match_depth = find_matching_handler_depth(handler, context)

            return false if match_depth.nil?
            return false unless all_auto_closeable?(context, match_depth)

            count = match_depth + 1
            count.times { context.pop }
            context.auto_close!(count)

            true
          end

          # Attempt to close the target tag and reopen any intervening
          # auto-closeable tags so subsequent content continues in the same
          # formatting context. Used when closing tags are not adjacent
          # (e.g. "[b][i]x[/b] more[/i]").
          #
          # @param handler [BaseHandler] the handler for the closing tag
          # @param context [ParserState]
          # @param tokens [Object, nil] the token stream (used to check that content follows)
          # @return [Boolean] true if successful, false otherwise
          def try_reopen(handler:, context:, tokens:)
            return false unless reopen_justified?(tokens)

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
            return false if match_depth.nil?

            opening_handlers = collect_auto_closeable_handlers(context, match_depth)
            return false if opening_handlers.empty?

            closing_handlers = [handler]
            closing_handlers.concat(peek_closing_handlers(tokens, opening_handlers.size - 1))
            return false if closing_handlers.size != opening_handlers.size
            unless opening_handlers.sort_by(&:object_id) == closing_handlers.sort_by(&:object_id)
              return false
            end

            # Consume the extra closing tags
            (opening_handlers.size - 1).times do
              peeked = tokens.peek
              break unless peeked.is_a?(TagEndToken)
              tokens.next
            end

            opening_handlers.each { context.pop }
            context.auto_close!(opening_handlers.size)

            true
          end

          private

          # Reopening only makes sense when there is upcoming content that
          # would benefit from the reopened context. If the next token is a
          # closing tag (or nothing), plain auto-close is correct.
          JUSTIFYING_NEXT_TOKENS = Set[TextToken, TagStartToken].freeze
          private_constant :JUSTIFYING_NEXT_TOKENS

          def reopen_justified?(tokens)
            JUSTIFYING_NEXT_TOKENS.member?(tokens&.peek&.class)
          end

          def find_matching_handler_depth(handler, context)
            elements = context.elements_from_current(MAX_AUTO_CLOSE_DEPTH - 1)

            elements.each_with_index do |element, depth|
              next unless element.is_a?(AST::Element)

              element_handler = @registry.handler_for_element(element)
              return depth if element_handler == handler
            end

            nil
          end

          def all_auto_closeable?(context, target_depth)
            context
              .elements_from_current(target_depth)
              .all? { |element| @registry.auto_closeable?(element.class) }
          end

          def collect_auto_closeable_handlers(context, target_depth)
            handlers = []

            context
              .elements_from_current(target_depth)
              .each do |element|
                return [] unless @registry.auto_closeable?(element.class)

                handler = @registry.handler_for_element(element)
                handlers << handler if handler
              end

            handlers
          end

          def peek_closing_handlers(tokens, max_count)
            handlers = []
            peeked_tokens = tokens.peek_ahead(max_count)

            peeked_tokens.each do |token|
              break unless token.is_a?(TagEndToken)

              handler = @registry[token.tag]
              break unless handler

              handlers << handler
            end

            handlers
          end
        end
      end
    end
  end
end
