# frozen_string_literal: true

module Markbridge
  module AST
    # Marker module for block-level AST nodes.
    #
    # The HTML parser uses this marker to apply browser-style whitespace
    # rules — specifically, it drops trailing whitespace on a block element's
    # previous sibling so authors can indent source HTML without ending up
    # with stray spaces before paragraph or list breaks in the output.
    #
    # Third-party AST extensions opt in by `include AST::Block` on any class
    # that should participate in this whitespace handling.
    #
    # @example
    #   class MyCustomBlock < Markbridge::AST::Element
    #     include Markbridge::AST::Block
    #   end
    module Block
    end
  end
end
