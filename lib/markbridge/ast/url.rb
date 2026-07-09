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

      # Whether this link is "bare" — it has no link text of its own:
      # either no children, or a single Text child whose content is
      # exactly the href (how parsers model a URL that stands for
      # itself). Consumers that record or rewrite links need this
      # judgment too (a bare URL must stay bare to keep autolinking
      # and oneboxing working), so it lives on the node rather than
      # in the renderer.
      #
      # @return [Boolean]
      def bare?
        return true if children.empty?

        children.size == 1 && children.first.instance_of?(Text) && children.first.text == href
      end
    end
  end
end
