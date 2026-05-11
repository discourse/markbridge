# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a list item within a {List}.
    #
    # @example
    #   item = AST::ListItem.new
    #   item << AST::Text.new("First item")
    class ListItem < Element
    end
  end
end
