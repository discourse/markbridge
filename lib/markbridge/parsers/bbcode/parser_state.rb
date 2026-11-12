# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Manages parsing state
      class ParserState
        MAX_DEPTH = 100

        attr_reader :current, :depth, :auto_closed_count, :depth_exceeded_count, :unclosed_raw_tags

        def initialize(root)
          @root = root
          @current = root
          @depth = 0
          @node_stack = [root]
          @auto_closed_count = 0
          @depth_exceeded_count = 0
          @unclosed_raw_tags = Hash.new(0)
          @ended_early = []
          @reopened = []
        end

        # Push a copy of an element that a mismatched closing tag has
        # ended, so what follows is still inside of it (see
        # TagReconciler#try_reopen).
        # At the depth limit nothing is opened again.
        # @param element [AST::Element] the copy, without children
        def reopen(element)
          return if @depth == MAX_DEPTH

          holder = @current
          push(element)
          # A list puts what is no item into an item of its own.
          holder = holder.children.last unless holder.children.last.equal?(element)
          @reopened << [holder, element]
        end

        # Take the reopened elements away that nothing was put into:
        # `[list][s][url=…]a[/s][*]b` opens the link again behind the
        # `[/s]`, and the `[*]` ends it at once. An empty link would be
        # written as its address. The last one first, so an element
        # that held only an empty one goes too.
        def drop_empty_reopened
          @reopened.reverse_each do |holder, element|
            next unless element.children.empty?

            holder.replace_children(holder.children.reject { |child| child.equal?(element) })
          end
        end

        # Remember an element that was ended by the closing tag of an
        # element around it, by what identifies its own closing tag.
        # @param key [Object]
        def end_early(key)
          @ended_early << key
        end

        # Whether an element with this key was ended early and its
        # closing tag has not come yet. The answer is yes only once per
        # element: the closing tag that comes for it is taken as that
        # one.
        # @param key [Object]
        # @return [Boolean]
        def closing_tag_due?(key)
          index = @ended_early.index(key)
          return false unless index

          @ended_early.delete_at(index)
          true
        end

        # Add element as child to current node and push the element onto the stack
        # Uses graceful degradation: if max depth is exceeded and token is provided,
        # treats the tag as text instead of raising. If no token is provided,
        # raises MaxDepthExceededError (for backwards compatibility).
        # @param element [AST::Element]
        # @param token [Token, nil] the token that created this element (for graceful degradation)
        # @return [Boolean] true if pushed successfully, false if depth exceeded
        # @raise [MaxDepthExceededError] when pushing would exceed MAX_DEPTH and no token provided
        def push(element, token: nil)
          if @depth == MAX_DEPTH
            raise MaxDepthExceededError, MAX_DEPTH unless token

            # Graceful degradation: treat as text
            @current << AST::Text.new(token.source)
            @depth_exceeded_count += 1
            return false
          end

          @current << element
          @current = element
          @node_stack << element
          @depth += 1
          true
        end

        # Pop current element and return to parent
        # @return [AST::Element] the parent node
        def pop
          return @root if @node_stack.size == 1

          @node_stack.pop
          @current = @node_stack.fetch(-1)
          @depth -= 1
          @current
        end

        # Add a child to current node without changing context
        # @param node [AST::Node]
        def add_child(node)
          @current << node
        end

        # Increment the count of auto-closed tags after external reconciliation
        # @param count [Integer]
        def auto_close!(count = 1)
          @auto_closed_count += count
        end

        # Mark a raw tag as unclosed (for tracking parsing issues)
        # @param tag_name [String]
        def mark_unclosed_raw!(tag_name)
          @unclosed_raw_tags[tag_name] += 1
        end

        # Return elements from the current node downward
        # @param limit [Integer, nil] number of elements to include from the top
        # @return [Array<AST::Node>]
        def elements_from_current(limit = nil)
          max_offset = @node_stack.size - 1
          limit = [limit || max_offset, max_offset].min
          (0..limit).map { |offset| @node_stack.fetch(max_offset - offset) }
        end
      end
    end
  end
end
