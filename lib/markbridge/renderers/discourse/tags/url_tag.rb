# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering URLs
        #
        # Bare URLs (a single Text child equal to the href, or no link
        # text at all) render as the plain href instead of a Markdown
        # link — in Discourse a bare URL on its own line oneboxes, a
        # `[text](url)` link does not.
        class UrlTag < Tag
          # Schemes that are safe to link. Anything else that *looks*
          # like a scheme (javascript:, data:, vbscript:, …) is dropped;
          # scheme-less hrefs (relative paths, anchors, protocol-relative
          # URLs) pass through — common in forum exports and harmless.
          ALLOWED_SCHEMES = /\A(?:https?|ftps?|mailto):/i
          SCHEME_LIKE = /\A[a-z][a-z0-9+.-]*:/i
          private_constant :ALLOWED_SCHEMES, :SCHEME_LIKE

          def render(element, interface)
            child_context = interface.with_parent(element)
            text = interface.render_children(element, context: child_context)
            href = element.href

            return text unless linkable?(href)

            if interface.html_mode?
              %(<a href="#{HtmlEscaper.escape(href)}">#{text}</a>)
            elsif bare?(element, text)
              href
            else
              "[#{text}](#{markdown_destination(href)})"
            end
          end

          private

          # CommonMark link destinations cannot contain whitespace unless
          # wrapped in <> — relevant for relative targets like MediaWiki
          # page names ("Main Page").
          def markdown_destination(href)
            href.match?(/\s/) ? "<#{href}>" : href
          end

          def linkable?(href)
            return false if href.nil? || href.empty?
            return true if href.match?(ALLOWED_SCHEMES)

            !href.match?(SCHEME_LIKE)
          end

          # Bare when there is no link text, or when the only child is a
          # Text node whose content is exactly the href (compared on the
          # AST, not on the rendered text, so Markdown escaping in the
          # label cannot break the detection).
          def bare?(element, rendered_text)
            return true if rendered_text.empty?

            children = element.children
            children.size == 1 && children.first.instance_of?(AST::Text) &&
              children.first.text == element.href
          end
        end
      end
    end
  end
end
