# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Library of rendering tags for different element types
      class TagLibrary
        def initialize
          @tags = {}
        end

        # Register a tag for an element class
        # @param element_class [Class] the element class
        # @param tag [Tag] the tag instance
        def register(element_class, tag)
          @tags[element_class] = tag
          self
        end

        # Get tag for an element class
        # @param element_class [Class]
        # @return [Tag, nil]
        def [](element_class)
          @tags[element_class]
        end

        # Auto-register all tags using naming convention
        # Convention: BoldTag handles AST::Bold, ItalicTag handles AST::Italic, etc.
        # @return [self]
        def auto_register!
          Tags.constants.each do |tag_constant|
            element_class = ast_class_for(tag_constant)
            register(element_class, Tags.const_get(tag_constant).new) if element_class
          end
          self
        end

        # Look up the AST element class matching a +XxxTag+ constant via the
        # +XxxTag → AST::Xxx+ naming convention.
        # @return [Class, nil]
        def ast_class_for(tag_constant)
          AST.const_get(tag_constant.to_s.sub(/Tag\z/, ""))
        rescue NameError
          nil
        end

        # Create the default tag library for Discourse Markdown
        # @return [TagLibrary]
        def self.default
          new.auto_register!
        end
      end
    end
  end
end
