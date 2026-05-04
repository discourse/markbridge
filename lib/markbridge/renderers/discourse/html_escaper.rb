# frozen_string_literal: true

require "cgi"

module Markbridge
  module Renderers
    module Discourse
      # Escapes text for safe inclusion in HTML output. Used when rendering
      # content inside a CommonMark HTML block (e.g. TableTag's fallback)
      # where Markdown-level escaping would not be applied.
      class HtmlEscaper
        # @param text [String, nil]
        # @return [String]
        def self.escape(text)
          CGI.escapeHTML(text || "")
        end
      end
    end
  end
end
