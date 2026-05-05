# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Interface that tags use for rendering operations
      # Decouples tags from renderer implementation details
      class RenderingInterface
        attr_reader :context

        def initialize(renderer, context)
          @renderer = renderer
          @context = context
        end

        # Core rendering operations
        def render_node(node, context: @context)
          @renderer.render(node, context:)
        end

        def render_children(element, context: @context)
          @renderer.render_children(element, context:)
        end

        # Append a record to the per-call emission buffer. Returns nil.
        # Used by Tags that need to surface side data (uploads,
        # placeholder records, etc.) to the caller via
        # +Conversion#emissions+. The Tag's render return value is
        # unaffected.
        # @param key [Symbol]
        # @param payload [Object]
        # @return [nil]
        def emit(key, payload)
          @renderer.record_emission(key, payload)
          nil
        end

        # Run the block; if the block exits without committing, any
        # emissions made inside it are rolled back. Used by tags that
        # speculatively render content they may discard (e.g.
        # +TableTag+'s Markdown-vs-HTML decision).
        #
        # @yieldparam controller [#commit] call +#commit+ to keep emissions
        # @return [Object] the block's return value
        def with_provisional_emissions(&)
          @renderer.with_provisional_emissions(&)
        end

        # Context operations
        def with_parent(element)
          @context.with_parent(element)
        end

        def with_html_mode(value)
          @context.with_html_mode(value)
        end

        def html_mode?
          @context.html_mode?
        end

        def find_parent(klass)
          @context.find_parent(klass)
        end

        def count_parents(klass)
          @context.count_parents(klass)
        end

        def has_parent?(klass)
          @context.has_parent?(klass)
        end

        def root?
          @context.root?
        end

        # Check if element should be rendered in block context
        # @param node [AST::Node] container node or leaf like HorizontalRule
        # @return [Boolean]
        def block_context?(node)
          # Check if it's a block-level element type (but not code, which can be inline)
          return true if node.instance_of?(AST::List) || node.instance_of?(AST::HorizontalRule)
          return false unless node.is_a?(AST::Element)

          # Check if content has newlines
          node.children.any? { |c| c.instance_of?(AST::Text) && c.text.include?("\n") }
        end

        # Helper: wrap inline content with markers
        # Handles edge cases like existing markers and whitespace
        def wrap_inline(content, open_marker, close_marker = nil)
          close_marker ||= open_marker
          return content unless content.match?(/\S/)

          # Handle conflicts with existing markers
          if content.include?(open_marker) || content.include?(close_marker)
            # Use HTML fallback for common cases
            case open_marker
            when "**"
              return "<strong>#{content}</strong>"
            when "*"
              return "<em>#{content}</em>"
            when "~~"
              return "<s>#{content}</s>"
            end
          end

          # Preserve leading/trailing whitespace
          content.sub(/\A(\s*)(.+?)(\s*)\z/m) do
            match = Regexp.last_match
            "#{match[1]}#{open_marker}#{match[2]}#{close_marker}#{match[3]}"
          end
        end
      end
    end
  end
end
