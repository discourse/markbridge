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
          # The whitespace in front of the text and after it.
          EDGES = /\A([[:space:]]*).*?([[:space:]]*)\z/m
          private_constant :ALLOWED_SCHEMES, :SCHEME_LIKE, :EDGES

          def render(element, interface)
            href = element.href
            linkable = linkable?(href)
            # Url#bare? judges the AST, so label escaping cannot confuse it.
            return bare_tokens(element, href) if linkable && element.bare?

            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            return tokens unless linkable
            # A label that renders to nothing (an empty formatting child)
            # or to whitespace only is no label either.
            return [Inline::Tokens.bare_url(href)] unless Inline::Tokens.visible?(tokens)

            tokens.unshift(Inline::Tokens.link_open(href)) << Inline::Tokens.link_close
          end

          private

          # The bare URL in place of the text. Whitespace at the edges of
          # the text and the line breaks in front of it and after it stay
          # outside the URL, so `[url] https://e.com [/url]` keeps its
          # spaces. A bare link has only Text and LineBreak children (see
          # Url#bare?); the line breaks are written as hard break tokens
          # here, the serializer picks their form.
          def bare_tokens(element, href)
            bare = Inline::Tokens.bare_url(href)
            return [bare] if element.children.empty?

            element
              .children
              .each_with_object([]) do |child, tokens|
                next tokens << Inline::Tokens.hard_break if child.instance_of?(AST::LineBreak)

                text = child.text
                next tokens << bare if text == href

                lead, trail = text.match(EDGES).captures
                tokens << Inline::Tokens.text(lead) unless lead.empty?
                tokens << bare
                tokens << Inline::Tokens.text(trail) unless trail.empty?
              end
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
