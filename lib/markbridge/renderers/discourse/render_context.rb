# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Immutable context for rendering that wraps the parent chain
      # Provides query methods to ask about parent elements without
      # the renderer knowing about specific element types
      #
      # Uses a hash-based cache for O(1) parent lookups instead of O(depth) scans
      class RenderContext
        attr_reader :parents, :depth

        def initialize(parents = [], parent_cache: nil)
          @parents = parents.freeze
          @depth = parents.size
          @parent_cache = parent_cache || build_cache(parents)
        end

        # Create new context with element added to parent chain
        # Incrementally updates cache instead of rebuilding from scratch
        # @param element [AST::Element]
        # @return [RenderContext]
        def with_parent(element)
          new_parents = @parents + [element]

          # Incrementally update cache instead of rebuilding
          new_cache = @parent_cache.dup
          element_class = element.class
          new_cache[element_class] ||= []
          new_cache[element_class] = new_cache[element_class] + [element]

          self.class.new(new_parents, parent_cache: new_cache)
        end

        # Find closest parent of given type
        # O(1) hash lookup instead of O(depth) scan
        # @param klass [Class]
        # @return [AST::Element, nil]
        def find_parent(klass)
          @parent_cache[klass]&.last
        end

        # Count parents of given type
        # O(1) instead of O(depth)
        # @param klass [Class]
        # @return [Integer]
        def count_parents(klass)
          @parent_cache[klass]&.size || 0
        end

        # Check if parent of type exists
        # O(1) check
        # @param klass [Class]
        # @return [Boolean]
        def has_parent?(klass)
          @parent_cache.key?(klass) && !@parent_cache[klass].empty?
        end

        # Check if we're at the root (no parents)
        # @return [Boolean]
        def root?
          @depth.zero?
        end

        private

        # Build cache from parents array
        # Groups parents by class for fast lookup
        # @param parents [Array<AST::Element>]
        # @return [Hash{Class => Array<AST::Element>}]
        def build_cache(parents)
          parents.each_with_object(Hash.new { |h, k| h[k] = [] }) do |parent, cache|
            cache[parent.class] = cache[parent.class] + [parent]
          end
        end
      end
    end
  end
end
