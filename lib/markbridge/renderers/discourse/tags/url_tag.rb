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
            elsif element.bare? || blank?(text)
              # Url#bare? judges the AST (so label escaping can't confuse
              # it); the rendered-text check additionally catches labels
              # that render to nothing (e.g. an empty formatting child)
              # or to whitespace only, which wrap_inline would leave
              # unlinked.
              bare_url(element, href, interface)
            else
              interface.wrap_inline(text, "[", "](#{markdown_destination(href)})")
            end
          end

          private

          # Unicode-aware, matching the guard in RenderingInterface#wrap_inline.
          def blank?(text)
            !text.match?(/[^[:space:]]/)
          end

          # A bare URL is linked by the Markdown parser on its own only when
          # whitespace (or the start of the line) stands in front of it and
          # nothing sticks to its end. Glued to text it is written as a
          # Markdown link with the URL as its text, which links everywhere,
          # also for a relative href. The glued form is not recognized as
          # a bare URL, so it cannot produce an inline onebox either.
          def bare_url(element, href, interface)
            glued =
              glued?(interface.previous_sibling(element), /\S\z/) ||
                glued?(interface.next_sibling(element), /\A\S/)
            glued ? "[#{href}](#{markdown_destination(href)})" : href
          end

          # Whether the neighbouring +node+ is text with something other
          # than whitespace at the edge next to the URL.
          def glued?(node, edge)
            node.instance_of?(AST::Text) && node.text.match?(edge)
          end

          # CommonMark link destinations cannot contain whitespace unless
          # wrapped in <> — relevant for relative targets like MediaWiki
          # page names ("Main Page"). An unbalanced parenthesis ends the
          # destination early, so every parenthesis gets a backslash;
          # balanced ones would be fine, but the check is not worth it. The
          # match? in front saves the copy that gsub makes also without a
          # match (a link is rendered often, a parenthesis in it is rare).
          def markdown_destination(href)
            destination = href.match?(/[()]/) ? href.gsub(/[()]/) { |char| "\\#{char}" } : href
            destination.match?(/\s/) ? "<#{destination}>" : destination
          end

          def linkable?(href)
            return false if href.nil? || href.empty?
            return true if href.match?(ALLOWED_SCHEMES)

            !href.match?(SCHEME_LIKE)
          end
        end
      end
    end
  end
end
