# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering list items
        class ListItemTag < Tag
          def initialize
            @builder = Builders::ListItemBuilder.new
          end

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context).strip
            return "" if content.empty?

            parent_list = interface.find_parent(AST::List)
            @builder.build(
              content,
              marker: determine_marker(parent_list),
              indent: calculate_indent(interface),
            )
          end

          private

          # @param parent_list [AST::List, nil]
          # @return [String]
          def determine_marker(parent_list)
            parent_list&.ordered? ? "1. " : "- "
          end

          # Each ancestor List (excluding the direct parent) contributes
          # indentation matching its own marker width:
          # ordered = "   " (3 chars for "1. "), unordered = "  " (2 chars for "- ").
          # @param interface [RenderingInterface]
          # @return [String]
          def calculate_indent(interface)
            ancestor_lists =
              interface.context.parents.select { |p| p.instance_of?(AST::List) }[0...-1]
            ancestor_lists.map { |list| list.ordered? ? "   " : "  " }.join
          end
        end
      end
    end
  end
end
