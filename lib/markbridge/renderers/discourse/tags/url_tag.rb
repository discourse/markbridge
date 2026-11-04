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
          # The text in front of a bare URL keeps it from being linked
          # unless it ends in whitespace or an opening parenthesis. These
          # are the characters that cmark-gfm accepts there, markdown-it
          # accepts more.
          GLUED_BEFORE = /[^[:space:](]\z/
          # Text after a bare URL glues to it, unless it starts with
          # whitespace or with punctuation that is followed by whitespace
          # or nothing (see #glued_after).
          GLUED_AFTER = /\A(?![.,:!?]*(?:[[:space:]]|\z))/
          GLUED_AFTER_PAREN_OK = /\A(?![.,:!?)]*(?:[[:space:]]|\z))/
          # Nodes that render as a block of their own, with line breaks
          # around them. Lists, rules and code blocks are in
          # RenderingInterface#block_context?.
          BLOCKS = [
            AST::Paragraph,
            AST::Quote,
            AST::Heading,
            AST::Align,
            AST::Details,
            AST::Table,
            AST::Poll,
            AST::Event,
          ].freeze
          private_constant :ALLOWED_SCHEMES,
                           :BLOCKS,
                           :SCHEME_LIKE,
                           :GLUED_BEFORE,
                           :GLUED_AFTER,
                           :GLUED_AFTER_PAREN_OK

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
              bare_url(element:, href:, text:, interface:)
            else
              interface.wrap_inline(text, "[", "](#{LinkDestination.escape(href)})")
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
          #
          # The label of that link is the rendered +text+, not the raw
          # href: the renderer has already escaped it for a link label,
          # a raw `]` in the href would end the label early. A link
          # without text, or with a label that renders to nothing, gets
          # the href rendered as text instead. Rendering the href every
          # time would give the same label, reusing +text+ saves a Text
          # node and a second escape (a quarter of the time of a glued
          # link).
          def bare_url(element:, href:, text:, interface:)
            glued =
              glued?(interface.previous_sibling(element), edge: GLUED_BEFORE, interface:) ||
                glued?(interface.next_sibling(element), edge: glued_after(href), interface:)
            return href unless glued

            label = blank?(text) ? href_as_text(element:, href:, interface:) : text
            "[#{label}](#{LinkDestination.escape(href)})"
          end

          def href_as_text(element:, href:, interface:)
            interface.render_node(AST::Text.new(href), context: interface.with_parent(element))
          end

          # Whether the neighboring +node+ would stop the Markdown parser
          # from linking the bare URL, or would become part of the link.
          # Text decides by the character at its +edge+. A line break or a
          # block starts a line of its own. Any other node is written right
          # next to the URL (inline code, emphasis, an image, ...), and the
          # link form is the one that works next to all of them.
          def glued?(node, edge:, interface:)
            case node
            when nil, AST::LineBreak
              false
            when AST::Text, AST::MarkdownText
              node.text.match?(edge)
            else
              !BLOCKS.any? { |block| node.is_a?(block) } && !interface.block_context?(node)
            end
          end

          # The text after the URL may start with punctuation that ends a
          # sentence: markdown-it (linkify) and cmark-gfm both leave it out
          # of the link, as long as whitespace or the end of the text
          # follows. A `)` only when the href has no parenthesis of its
          # own: both parsers count them and keep a `)` that closes one
          # in the link.
          def glued_after(href)
            href.match?(/[()]/) ? GLUED_AFTER : GLUED_AFTER_PAREN_OK
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
