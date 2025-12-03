# frozen_string_literal: true

module Markbridge
  module AST
    # Represents an inline or block code element.
    #
    # @example Inline code
    #   code = AST::Code.new
    #   code << AST::Text.new("puts 'hello'")
    #
    # @example Code with language for syntax highlighting
    #   code = AST::Code.new(language: "ruby")
    #   code << AST::Text.new("def hello\n  puts 'world'\nend")
    class Code < Element
      # @return [String, nil] the programming language for syntax highlighting
      attr_reader :language

      # Create a new code element.
      #
      # @param language [String, nil] optional language identifier for syntax highlighting
      def initialize(language: nil)
        super()
        @language = language
      end
    end
  end
end
