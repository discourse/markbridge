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
        #
        # A frozen source also carries flattened ancestry entries (see
        # {#freeze}); the copy is mutable again, so those entries are
        # dropped and the copy goes back to the lazy {#resolve} lookup.
        # Keeping them would bake in inheritance decisions from before
        # any changes made to the copy.
        def initialize_copy(other)
          super
          @tags = @tags.dup
          @flattened_classes&.each { |klass| @tags.delete(klass) }
          @flattened_classes = nil
        end

        # Register a tag for an element class
        # @param element_class [Class] the element class
        # @param tag [Tag] the tag instance
        def register(element_class, tag)
          @tags[element_class] = tag
          self
        end

        # Remove the binding for this exact element class. Lookup then
        # falls back to the nearest ancestor class with a tag; when no
        # ancestor has one — true for every built-in class, since
        # nothing binds +AST::Element+ or +AST::Node+ — the renderer
        # falls through to +render_children+. See +Renderer#render+.
        #
        # @param element_class [Class]
        # @return [self]
        def unregister(element_class)
          @tags.delete(element_class)
          self
        end

        # Merge a Hash of class → Tag mappings on top of this library
        # in-place. A +nil+ value unregisters the corresponding class
        # (see {#unregister} for what lookup does then).
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

        # Find the tag for +element_class+ through its ancestry: walk the
        # superclass chain, starting at +element_class.superclass+, and
        # return the first registered tag. The walk stays inside the
        # +AST::Node+ hierarchy, so a tag registered for a class outside
        # the AST is never found. The exact-class lookup is {#[]};
        # callers check that first.
        #
        # @param element_class [Class]
        # @return [Tag, nil]
        def resolve(element_class)
          klass = element_class.superclass
          while klass && klass <= AST::Node
            tag = self[klass]
            return tag if tag

            klass = klass.superclass
          end
          # The while loop's own value is nil, so a miss returns nil.
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
        #
        # Freezing also flattens ancestry resolution: every known AST
        # class without an explicit binding whose ancestry resolves to a
        # tag gets that tag copied into the internal Hash, so lookup on a
        # frozen library is a single exact Hash hit for those classes
        # too. +AST::Node.descendants+ is boot-time state, so only
        # classes defined before the freeze are covered; later classes
        # keep working through the renderer's lazy {#resolve} fallback.
        def freeze
          flatten_ancestry!
          @tags.freeze
          super
        end

        private

        # See {#freeze}. Records what it added in +@flattened_classes+ so
        # {#initialize_copy} can drop those entries from a copy again.
        def flatten_ancestry!
          AST::Node.descendants.each do |klass|
            next if @tags.key?(klass)

            tag = resolve(klass)
            next unless tag

            (@flattened_classes ||= []) << klass
            @tags[klass] = tag
          end
        end
      end
    end
  end
end
