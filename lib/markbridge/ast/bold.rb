# frozen_string_literal: true

module Markbridge
  module AST
    # Represents bold/strong text formatting.
    #
    # @example
    #   bold = AST::Bold.new
    #   bold << AST::Text.new("important text")
    class Bold < Element
    end
  end
end
