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
            tag_class = Tags.const_get(tag_constant)
            next unless tag_class.is_a?(Class) && tag_class < Tag

            # Extract element name from tag name: BoldTag → Bold
            element_name = tag_constant.to_s.sub(/Tag$/, "")
            element_class =
              begin
                AST.const_get(element_name)
              rescue StandardError
                nil
              end

            register(element_class, tag_class.new) if element_class
          end

          self
        end

        # Create the default tag library for Discourse Markdown
        # @return [TagLibrary]
        def self.default
          library = new

          # Auto-register tags based on naming convention
          library.auto_register!

          # Special cases: inline tags that don't follow the convention
          library.register AST::LineBreak, Tags::LineBreakTag.new
          library.register AST::HorizontalRule, Tags::HorizontalRuleTag.new

          library
        end
      end
    end
  end
end
