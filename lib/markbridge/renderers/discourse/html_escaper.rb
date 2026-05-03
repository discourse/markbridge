# frozen_string_literal: true

require "cgi"

module Markbridge
  module Renderers
    module Discourse
      # Escapes text for safe inclusion in HTML output.
      # Used when rendering content inside an HTML context (e.g. inside an
      # HTML <table> fallback) where Markdown escaping would not be parsed.
      class HtmlEscaper
        # @param text [String, nil]
        # @return [String]
        def escape(text)
          CGI.escapeHTML(text || "")
        end

        # @param text [String, nil]
        # @return [String]
        def self.escape(text)
          CGI.escapeHTML(text || "")
        end
      end
    end
  end
end
