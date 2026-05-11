# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a quote/blockquote element.
    #
    # @example Basic quote
    #   quote = AST::Quote.new
    #   quote << AST::Text.new("quoted text")
    #
    # @example Quote with author attribution
    #   quote = AST::Quote.new(author: "John")
    #   quote << AST::Text.new("quoted text")
    #
    # @example Quote with full Discourse context
    #   quote = AST::Quote.new(author: "John", post: "123", topic: "456", username: "john123")
    #   quote << AST::Text.new("quoted text")
    class Quote < Element
      # @return [String, nil] the author/username of the quote
      attr_reader :author

      # @return [String, nil] the post ID for Discourse quotes
      attr_reader :post

      # @return [String, nil] the topic ID for Discourse quotes
      attr_reader :topic

      # @return [String, nil] the username for Discourse quotes
      attr_reader :username

      # Create a new Quote element.
      #
      # @param author [String, nil] the author attribution
      # @param post [String, nil] the post ID (Discourse-specific)
      # @param topic [String, nil] the topic ID (Discourse-specific)
      # @param username [String, nil] the username (Discourse-specific)
      def initialize(author: nil, post: nil, topic: nil, username: nil)
        super()
        @author = author
        @post = post
        @topic = topic
        @username = username
      end
    end
  end
end
