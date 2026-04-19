# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Renders AST to Discourse-flavored Markdown in-memory.
      class Renderer
        def initialize(tag_library: nil, escaper: nil)
          @tag_library = tag_library || TagLibrary.default
          @escaper = escaper || MarkdownEscaper.new
        end

        # Render a node to Markdown
        # @param node [AST::Node]
        # @param context [RenderContext] rendering context with parent chain
        # @return [String]
        def render(node, context: RenderContext.new)
          tag = @tag_library[node.class]
          return tag.render(node, interface_for(context)) if tag

          case node
          when AST::Element # Document is an Element subclass
            render_children(node, context:)
          when AST::MarkdownText
            # Pass through markdown text as-is (already formatted)
            node.text
          when AST::Text
            # Escape plain text unless we're inside a code block
            context.has_parent?(AST::Code) ? node.text : @escaper.escape(node.text)
          else
            ""
          end
        end

        # Render all children of a node
        # @param node [AST::Element]
        # @param context [RenderContext] rendering context
        # @return [String]
        def render_children(node, context:)
          result = +""
          node.children.each do |child|
            part = render(child, context:)
            result << EMPHASIS_BOUNDARY if emphasis_delimiter_clash?(result[-1], part[0])
            result << part
          end
          result
        end

        private

        # Inserted between sibling outputs when their adjacent characters
        # would merge into a longer Markdown emphasis delimiter run (e.g.
        # `***` + `*...` becoming `****...`). The HTML comment is invisible
        # in rendered output but breaks the delimiter run during Markdown
        # parsing.
        EMPHASIS_BOUNDARY = "<!---->"
        # Characters where adjacent runs merge into a single longer run during
        # Markdown parsing: emphasis (* _), strikethrough (~), code spans (`).
        EMPHASIS_DELIMITERS = %w[* _ ~ `].freeze
        private_constant :EMPHASIS_BOUNDARY, :EMPHASIS_DELIMITERS

        def emphasis_delimiter_clash?(last_char, first_char)
          last_char == first_char && EMPHASIS_DELIMITERS.include?(last_char)
        end

        def interface_for(context)
          RenderingInterface.new(self, context)
        end
      end
    end
  end
end
