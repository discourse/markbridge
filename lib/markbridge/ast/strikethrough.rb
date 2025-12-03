# frozen_string_literal: true

module Markbridge
  module AST
    # Represents strikethrough/deleted text formatting.
    #
    # @example
    #   strikethrough = AST::Strikethrough.new
    #   strikethrough << AST::Text.new("deleted text")
    class Strikethrough < Element
    end
  end
end
