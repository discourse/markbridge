# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a hyperlink/URL element.
    #
    # @example URL with explicit href
    #   url = AST::Url.new(href: "https://example.com")
    #   url << AST::Text.new("Click here")
    #
    # @example URL with text as href
    #   url = AST::Url.new(href: "https://example.com")
    #   url << AST::Text.new("https://example.com")
    class Url < Element
      # @return [String, nil] the URL/href for this link
      attr_reader :href

      # Create a new URL element.
      #
      # @param href [String, nil] the URL/href for this link
      def initialize(href: nil)
        super()
        @href = href
      end
    end
  end
end
