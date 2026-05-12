# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Immutable context for rendering that wraps the parent chain.
      # Provides query methods to ask about parent elements without the
      # renderer knowing about specific element types.
      class RenderContext
        attr_reader :parents, :depth

        def initialize(parents = [], html_mode: false)
          @parents = parents.freeze
          @depth = parents.size
          @html_mode = html_mode
        end

        # Create new context with element added to parent chain.
        # @param element [AST::Element]
        # @return [RenderContext]
        def with_parent(element)
          self.class.new(@parents + [element], html_mode: @html_mode)
        end

        # Create new context with html_mode toggled.
        # @param value [Boolean]
        # @return [RenderContext]
        def with_html_mode(value)
          self.class.new(@parents, html_mode: value)
        end

        # @return [Boolean]
        def html_mode?
          @html_mode
        end

        # Find closest parent that is_a? klass (handles subclasses).
        # @param klass [Class]
        # @return [AST::Element, nil]
        def find_parent(klass)
          @parents.reverse_each.find { |parent| parent.is_a?(klass) }
        end

        # Count parents that are is_a? klass (handles subclasses).
        # @param klass [Class]
        # @return [Integer]
        def count_parents(klass)
          @parents.count { |parent| parent.is_a?(klass) }
        end

        # Check if any parent is_a? klass (handles subclasses).
        # @param klass [Class]
        # @return [Boolean]
        def has_parent?(klass)
          @parents.any? { |parent| parent.is_a?(klass) }
        end

        # Check if we're at the root (no parents).
        # @return [Boolean]
        def root?
          @depth.zero?
        end
      end
    end
  end
end
