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

      # @return [Boolean, nil] +true+ forces a fenced block; anything else
      #   leaves the block-or-inline decision to the renderer
      attr_reader :block

      # Create a new code element.
      #
      # @param language [String, nil] optional language identifier for syntax highlighting
      # @param block [Boolean, nil] +true+ when the source construct is a code
      #   block by definition (e.g. +<pre>+), even with single-line content
      def initialize(language: nil, block: nil)
        super()
        @language = language
        @block = block
      end
    end
  end
end
