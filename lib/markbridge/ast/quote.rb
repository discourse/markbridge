# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a quote/blockquote element.
    #
    # The attribution fields follow Discourse's quote format
    # (`[quote="username, post:2, topic:456"]`): +post_number+ is the
    # position of the quoted post *within its topic* (not a database
    # id), +topic_id+ is the topic's id. Sources that attribute quotes
    # by database id instead (phpBB, XenForo) use +post_id+ and
    # +user_id+ — those never feed a Discourse +post:+ reference and
    # are carried for consumers to remap.
    #
    # @example Basic quote
    #   quote = AST::Quote.new
    #   quote << AST::Text.new("quoted text")
    #
    # @example Quote with author attribution
    #   quote = AST::Quote.new(author: "alice")
    #   quote << AST::Text.new("quoted text")
    #
    # @example Quote with full Discourse context
    #   quote = AST::Quote.new(author: "alice", post_number: 123, topic_id: 456, username: "alice_b")
    #   quote << AST::Text.new("quoted text")
    class Quote < Element
      # @return [String, nil] the author attribution (display name)
      attr_reader :author

      # @return [Integer, nil] the quoted post's number within its topic
      #   (Discourse semantics — not a post id)
      attr_reader :post_number

      # @return [Integer, nil] the quoted post's database id, for sources
      #   that attribute quotes by id (phpBB's +post_id+, XenForo's
      #   +post:+). Distinct from {#post_number}; parsers map whichever
      #   their dialect provides.
      attr_reader :post_id

      # @return [Integer, nil] the topic id the quoted post belongs to
      attr_reader :topic_id

      # @return [String, nil] the quoted user's username
      attr_reader :username

      # @return [Integer, nil] the quoted user's id, for sources that
      #   attribute quotes by id (usernames may be unknown or stale)
      attr_reader :user_id

      # Create a new Quote element.
      #
      # @param author [String, nil] the author attribution (display name)
      # @param post_number [Integer, nil] the quoted post's number within its topic
      # @param post_id [Integer, nil] the quoted post's database id
      # @param topic_id [Integer, nil] the topic id
      # @param username [String, nil] the quoted user's username
      # @param user_id [Integer, nil] the quoted user's id
      def initialize(
        author: nil,
        post_number: nil,
        post_id: nil,
        topic_id: nil,
        username: nil,
        user_id: nil
      )
        super()
        @author = author
        @post_number = post_number
        @post_id = post_id
        @topic_id = topic_id
        @username = username
        @user_id = user_id
      end
    end
  end
end
