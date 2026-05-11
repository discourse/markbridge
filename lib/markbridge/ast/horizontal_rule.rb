# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a horizontal rule/divider.
    #
    # @example
    #   hr = AST::HorizontalRule.new
    class HorizontalRule < Node
      include Block
    end
  end
end
