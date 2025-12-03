# frozen_string_literal: true

module Markbridge
  module AST
    # Represents an email link element.
    #
    # @example Email with explicit address
    #   email = AST::Email.new(address: "[email protected]")
    #   email << AST::Text.new("Contact us")
    #
    # @example Email with text as address
    #   email = AST::Email.new(address: "[email protected]")
    #   email << AST::Text.new("[email protected]")
    class Email < Element
      # @return [String, nil] the email address for this link
      attr_reader :address

      # Create a new Email element.
      #
      # @param address [String, nil] the email address for this link
      def initialize(address: nil)
        super()
        @address = address
      end
    end
  end
end
