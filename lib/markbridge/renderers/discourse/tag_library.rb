# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Library of rendering tags for different element types
      class TagLibrary
        include Enumerable

        def initialize
          @tags = {}
        end

        # When a TagLibrary is +dup+'d / +clone+'d, ensure the
        # internal +@tags+ Hash is independent of the source. Without
        # this, both copies would share the same underlying Hash and
        # mutations to one would silently affect the other.
        def initialize_copy(other)
          super
          @tags = @tags.dup
        end

        # Register a tag for an element class
        # @param element_class [Class] the element class
        # @param tag [Tag] the tag instance
        def register(element_class, tag)
          @tags[element_class] = tag
          self
        end

        # Remove a tag binding so the renderer falls through to
        # +render_children+ for that element class. See
        # +Renderer#render+ for the auto-passthrough path.
        #
        # @param element_class [Class]
        # @return [self]
        def unregister(element_class)
          @tags.delete(element_class)
          self
        end

        # Merge a Hash of class → Tag mappings on top of this library
        # in-place. A +nil+ value unregisters the corresponding class
        # (so the default auto-passthrough kicks in).
        #
        # Named with a trailing +!+ because it mutates +self+ —
        # mirroring Ruby's Hash#merge / Hash#merge! convention. Use
        # +dup+ first if you need a non-destructive merge.
        #
        # @param mapping [Hash{Class => Tag, nil}]
        # @return [self]
        def merge!(mapping)
          mapping.each_pair do |klass, tag|
            if tag.nil?
              unregister(klass)
            else
              register(klass, tag)
            end
          end
          self
        end

        # Get tag for an element class
        # @param element_class [Class]
        # @return [Tag, nil]
        def [](element_class)
          @tags[element_class]
        end

        # Iterate over registered (element_class, tag) pairs.
        # Useful for debugging custom libraries — e.g. confirming an override
        # has stuck. Iteration order matches registration order.
        # @yieldparam element_class [Class]
        # @yieldparam tag [Tag]
        # @return [Enumerator] when no block is given
        def each(&block)
          @tags.each(&block)
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

        # Create the default tag library for Discourse Markdown.
        #
        # Each call returns a *fresh* instance — mutations made to one will
        # not be visible to another.
        #
        # @return [TagLibrary]
        def self.default
          new.auto_register!
        end

        # Shared, deep-frozen default library for the no-customization
        # fast path. Built once per process; {Renderer} falls back to it
        # when no +tag_library:+ is given, skipping the constant-scan and
        # ~30 tag instantiations of {.default} on every render. Tags are
        # stateless, so sharing is safe across renderers and threads.
        # +dup+ yields a mutable copy (see {#initialize_copy}).
        #
        # @return [TagLibrary] the same frozen instance on every call
        def self.shared_default
          @shared_default ||= default.freeze
        end

        # Freeze the library together with its internal Hash so that
        # registration on a shared instance fails loudly instead of
        # silently mutating state visible to every renderer.
        def freeze
          @tags.freeze
          super
        end
      end
    end
  end
end
