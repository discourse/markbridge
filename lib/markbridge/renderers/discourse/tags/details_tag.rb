# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Renders {AST::Details} as the +[details="…"]…[/details]+ block of
        # the discourse-details plugin.
        #
        # Markdown form: the BBCode has blank lines around it, so
        # consecutive details blocks don't merge and inline content next
        # to the block starts a new paragraph. The content inside is
        # stripped, so the opening tag and the body stand on adjacent
        # lines.
        #
        # html_mode form: a raw +<details><summary>…</summary>…</details>+,
        # with the title HTML-escaped.
        #
        # With +bbcode: false+, for a site without the plugin, the title is
        # a paragraph in bold in front of the content. Discourse core's
        # sanitizer has no +<details>+, so there is no HTML form.
        class DetailsTag < Tag
          DEFAULT_TITLE = "Summary"
          private_constant :DEFAULT_TITLE

          # @param bbcode [Boolean] write the BBCode of the plugin
          def initialize(bbcode: true)
            @bbcode = bbcode
          end

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context).strip

            # A details block with nothing to show renders to nothing —
            # an empty [details] shell would only add noise to the output.
            return "" if content.empty?

            return without_plugin(element, content, interface, child_context) unless @bbcode
            return render_html(element.title, content) if interface.html_mode?

            # Blank lines keep the content apart from the two tag lines:
            # a table right in front of the closing tag would take the
            # tag line as a row, and a `---` right after the opening tag
            # would make it a heading. Discourse finds the closing tag
            # line first and reads the lines between as blocks, so the
            # blank lines change nothing there.
            opener = element.title ? %([details="#{element.title}"]) : "[details]"
            "\n\n#{opener}\n\n#{content}\n\n[/details]\n\n"
          end

          private

          def render_html(title, content)
            label = title ? HtmlEscaper.escape(title) : DEFAULT_TITLE
            "<details><summary>#{label}</summary>#{content}</details>"
          end

          # The title as a paragraph in bold, rendered like any paragraph,
          # then the content.
          def without_plugin(element, content, interface, context)
            title = element.title.to_s.strip
            html = interface.html_mode?
            return html ? content : "\n\n#{content}\n\n" if title.empty?

            paragraph = AST::Paragraph.new << (AST::Bold.new << AST::Text.new(title))
            heading = interface.render_node(paragraph, context:)
            html ? "#{heading}#{content}" : "\n\n#{heading.strip}\n\n#{content}\n\n"
          end
        end
      end
    end
  end
end
