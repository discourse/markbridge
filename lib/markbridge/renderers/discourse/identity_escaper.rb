# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Pass-through escaper. Returns its input unchanged.
      #
      # Useful for migration paths where the source content is already
      # valid Markdown (or otherwise trusted not to need escaping) and
      # should reach the postprocessor verbatim. For *partial*
      # passthrough (e.g. allow lists but still escape headings), see
      # {MarkdownEscaper#initialize}'s +allow:+ kwarg.
      #
      # @example Per-call use via the renderer factory
      #   renderer = Markbridge.discourse_renderer(escape: false)
      #   Markbridge.bbcode_to_markdown(post.body, renderer:)
      class IdentityEscaper
        # @param text [String, nil]
        # @param in_link_label [Boolean] when true, escape +]+ so the
        #   text can be spliced into a Markdown link label
        #   +[text](url)+ without terminating it early. Mirrors
        #   {MarkdownEscaper#escape}'s +in_link_label:+. This isn't a
        #   stylistic escape — without it, trusted-Markdown content
        #   containing +]+ inside a +Url+/+Email+ ancestor produces a
        #   broken link.
        # @return [String] +text+ with +]+ optionally escaped, or
        #   +""+ when +text+ is nil
        def escape(text, in_link_label: false)
          return "" if text.nil?
          return text.gsub("]", "\\]") if in_link_label && text.include?("]")

          text
        end
      end
    end
  end
end
