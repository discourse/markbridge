# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering list items
        class ListItemTag < Tag
          def initialize
            super
            @builder = Builders::ListItemBuilder.new
          end

          def render(element, interface)
            # Create new context with this list item as parent
            child_context = interface.with_parent(element)

            # Render children with updated context
            content = interface.render_children(element, context: child_context).strip
            return "" if content.empty?

            # Get parent list to determine marker
            parent_list = interface.find_parent(AST::List)
            marker = determine_marker(parent_list)

            # Calculate indentation based on ancestor lists
            indent = calculate_indent(interface)

            # Delegate formatting to builder
            @builder.build(content, marker:, indent:)
          end

          private

          # Determine the list marker based on parent list type
          # @param parent_list [AST::List, nil]
          # @return [String]
          def determine_marker(parent_list)
            parent_list&.ordered? ? "1. " : "- "
          end

          # Calculate indentation for this list item
          # @param interface [RenderingInterface]
          # @return [String]
          def calculate_indent(interface)
            # Calculate indentation: count ancestor Lists (not including direct parent)
            # The direct parent List shouldn't add indentation, only grandparent Lists
            list_count = interface.count_parents(AST::List)
            # Subtract 1 because the immediate parent list doesn't contribute to indent
            ancestor_lists = list_count.positive? ? list_count - 1 : 0

            # Indentation width depends on markers of ancestor lists
            # Walk up the context to determine correct indentation
            calculate_indent_from_ancestors(interface.context, ancestor_lists)
          end

          # Calculate the correct indentation for nested list items
          # Each level matches the marker width of its parent: ordered="1. " (3 chars), unordered="- " (2 chars)
          # @param context [RenderContext] the rendering context
          # @param ancestor_count [Integer] number of ancestor lists
          # @return [String] the indentation string
          def calculate_indent_from_ancestors(context, ancestor_count)
            return "" if ancestor_count.zero?

            # Walk through parents from outermost to innermost to build indentation
            # Each ancestor contributes indentation based on ITS OWN marker width
            lists = context.parents.select { |p| p.is_a?(AST::List) }

            # Skip the immediate parent (last list in the array)
            ancestor_lists = lists[0...-1]

            # Build indentation string
            indent = ""
            ancestor_lists
              .first(ancestor_count)
              .each do |list|
                # Each level's indentation matches that list's marker width
                indent += list.ordered? ? "   " : "  "
              end

            indent
          end
        end
      end
    end
  end
end
