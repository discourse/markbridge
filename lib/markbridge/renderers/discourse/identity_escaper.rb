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
        # @return [String] +text+ unchanged, or +""+ when +text+ is nil
        def escape(text)
          text || ""
        end
      end
    end
  end
end
