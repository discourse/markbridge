# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Renders AST to Discourse-flavored Markdown in-memory.
      class Renderer
        def initialize(tag_library: nil, escaper: nil, html_escaper: nil)
          @tag_library = tag_library || TagLibrary.default
          @escaper = escaper || MarkdownEscaper.new
          @html_escaper = html_escaper || HtmlEscaper.new
          # @interface_cache is lazily initialized in #render's top-level
          # call and reset to nil after the call completes. No init
          # needed here — unset ivar returns nil under `.nil?` check.
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
            output = tag.render(node, interface)
            # Tags that haven't been audited for html_mode are wrapped in blank
            # lines so CommonMark renders their (possibly Markdown) output as a
            # Markdown island inside the surrounding HTML block.
            output = "\n\n#{output}\n\n" if context.html_mode? && !tag.html_mode_aware?
            return output
          end

          case node
          when AST::Element # Document is an Element subclass
            render_children(node, context:)
          when AST::MarkdownText
            render_markdown_text(node, context)
          when AST::Text
            render_text(node, context)
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
          result = +""
          node.children.each do |child|
            part = render(child, context:)
            next if part.empty?

            # Integer-byte check avoids allocating substrings for the
            # per-child adjacency probe. EMPHASIS_DELIMITER_BYTES.include?
            # over a 4-element Set is O(1).
            if !result.empty? && (last_byte = result.getbyte(-1)) == part.getbyte(0) &&
                 EMPHASIS_DELIMITER_BYTES.include?(last_byte)
              result << EMPHASIS_BOUNDARY
            end
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
        # Bytes where adjacent runs merge into a single longer run during
        # Markdown parsing: emphasis (* _), strikethrough (~), code spans (`).
        EMPHASIS_DELIMITER_BYTES = Set[42, 95, 126, 96].freeze
        private_constant :EMPHASIS_BOUNDARY, :EMPHASIS_DELIMITER_BYTES

        def interface_for(context)
          @interface_cache[context.object_id] ||= RenderingInterface.new(self, context)
        end

        # In html_mode, surround pre-formatted Markdown with blank lines so that
        # CommonMark terminates the enclosing HTML block (e.g. <table>) and
        # parses the content as Markdown before the closing tags reopen another
        # HTML block.
        def render_markdown_text(node, context)
          context.html_mode? ? "\n\n#{node.text}\n\n" : node.text
        end

        def render_text(node, context)
          # In html_mode even inside a code block we must HTML-escape, otherwise a
          # stray `<` in a code cell would break the surrounding <td>.
          if context.has_parent?(AST::Code)
            context.html_mode? ? @html_escaper.escape(node.text) : node.text
          elsif context.html_mode?
            @html_escaper.escape(node.text)
          else
            @escaper.escape(node.text)
          end
        end
      end
    end
  end
end
