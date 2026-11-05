# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Links. A bare link (no text of its own, or a text that is the
        # href, or a label with nothing visible in it) is a bare URL token:
        # the serializer decides from the neighbors whether it can stay
        # bare, which oneboxes in Discourse, or has to be written as
        # `[url](url)`. Any other link is a link token pair around the
        # children.
        class UrlTag < Tag
          # Schemes that are safe to link. Anything else that *looks*
          # like a scheme (javascript:, data:, vbscript:, …) is dropped;
          # scheme-less hrefs (relative paths, anchors, protocol-relative
          # URLs) pass through — common in forum exports and harmless.
          ALLOWED_SCHEMES = /\A(?:https?|ftps?|mailto):/i
          SCHEME_LIKE = /\A[a-z][a-z0-9+.-]*:/i
          private_constant :ALLOWED_SCHEMES, :SCHEME_LIKE

          def render(element, interface)
            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            href = element.href
            return tokens unless linkable?(href)

            # Url#bare? judges the AST (so label escaping cannot confuse
            # it); the token check additionally catches labels that
            # render to nothing (e.g. an empty formatting child) or to
            # whitespace only.
            if element.bare? || !Inline::Tokens.visible?(tokens)
              return [Inline::Tokens.bare_url(href)]
            end

            tokens.unshift(Inline::Tokens.link_open(href)) << Inline::Tokens.link_close
          end

          private

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
