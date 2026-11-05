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
      # Whitespace at the start or at the end of the text.
      EDGE_SPACE = /\A[[:space:]]+|[[:space:]]+\z/
      private_constant :EDGE_SPACE

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
      # either no children, or a single Text child whose content is the
      # href (how parsers model a URL that stands for itself).
      # Whitespace at the edges of the text and line breaks in front of
      # it or after it don't count: forum posts often have
      # `[url] https://example.com [/url]` or a line break right after
      # `[url]`. Consumers that record or rewrite links need this
      # judgment too (a bare URL must stay bare to keep autolinking
      # and oneboxing working), so it lives on the node rather than
      # in the renderer.
      #
      # @return [Boolean]
      # @example
      #   url = AST::Url.new(href: "https://example.com")
      #   url << AST::LineBreak.new << AST::Text.new(" https://example.com ")
      #   url.bare? # => true
      def bare?
        return true if children.empty?

        text = nil
        children.each do |child|
          if child.instance_of?(Text)
            return false if text

            text = child.text
          elsif !child.instance_of?(LineBreak)
            return false
          end
        end
        !text.nil? && (text == href || text.gsub(EDGE_SPACE, "") == href)
      end
    end
  end
end
