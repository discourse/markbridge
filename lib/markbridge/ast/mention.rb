# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a user or group mention (@username or @groupname).
    #
    # @example User mention
    #   mention = AST::Mention.new(name: "gerhard", type: :user)
    #
    # @example Group mention
    #   mention = AST::Mention.new(name: "Testers", type: :group)
    class Mention < Node
      # @return [String] the username or group name (without @)
      attr_reader :name

      # @return [Symbol] the type of mention (:user or :group)
      attr_reader :type

      # Create a new Mention node.
      #
      # @param name [String] the username or group name (without @)
      # @param type [Symbol] the type of mention (:user or :group), defaults to :user
      def initialize(name:, type: :user)
        @name = name
        @type = type
      end
    end
  end
end
