# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Renders AST to Discourse-flavored Markdown in-memory.
      class Renderer
        def initialize(tag_library: nil)
          @tag_library = tag_library || TagLibrary.default
        end

        # Render a node to Markdown
        # @param node [AST::Node]
        # @param context [RenderContext] rendering context with parent chain
        # @return [String]
        def render(node, context: RenderContext.new)
          root_call = @interface_cache.nil?
          @interface_cache ||= {}

          tag = @tag_library[node.class]
          if tag
            interface = interface_for(context)
            return tag.render(node, interface)
          end

          case node
          when AST::Document, AST::Element
            render_children(node, context:)
          when AST::Text
            node.text
          else
            ""
          end
        ensure
          @interface_cache = nil if root_call
        end

        # Render all children of a node
        # @param node [AST::Element]
        # @param context [RenderContext] rendering context
        # @return [String]
        def render_children(node, context:)
          node.children.map { |child| render(child, context:) }.join
        end

        private

        def interface_for(context)
          @interface_cache[context.object_id] ||= RenderingInterface.new(self, context)
        end
      end
    end
  end
end
