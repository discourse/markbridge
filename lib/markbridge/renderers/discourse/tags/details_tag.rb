# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Renders {AST::Details} as a Discourse +[details=…]…[/details]+
        # collapsible block.
        #
        # Markdown form: the BBCode is bracketed with leading and trailing
        # blank lines so consecutive details blocks don't merge and
        # adjacent inline content starts a new paragraph against the
        # block. Inside, the rendered children are stripped so the
        # +[details]+ opener and the body sit on adjacent lines without
        # a stray blank between them — matching Discourse's BBCode
        # parser expectations.
        #
        # HTML-block form (inside a CommonMark HTML block — when
        # +interface.html_mode?+ is +true+): a raw
        # +<details><summary>…</summary>…</details>+ element. The
        # +title+ is HTML-escaped for the +<summary>+ text.
        class DetailsTag < Tag
          DEFAULT_TITLE = "Summary"
          private_constant :DEFAULT_TITLE

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            return render_html(element.title, content) if interface.html_mode?

            opener = element.title ? %([details="#{element.title}"]) : "[details]"
            "\n\n#{opener}\n#{content.strip}\n[/details]\n\n"
          end

          private

          def render_html(title, content)
            label = title ? HtmlEscaper.escape(title) : DEFAULT_TITLE
            "<details><summary>#{label}</summary>#{content}</details>"
          end
        end
      end
    end
  end
end
