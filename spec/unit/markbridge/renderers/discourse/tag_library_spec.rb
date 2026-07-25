# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::TagLibrary do
  let(:library) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }

  describe "#register" do
    it "registers a tag for an element class" do
      tag = Markbridge::Renderers::Discourse::Tag.new { "test" }
      library.register(Markbridge::AST::Bold, tag)

      expect(library[Markbridge::AST::Bold]).to eq(tag)
    end

    it "returns self for chaining" do
      tag = Markbridge::Renderers::Discourse::Tag.new { "test" }
      result = library.register(Markbridge::AST::Bold, tag)

      expect(result).to eq(library)
    end
  end

  describe "#[]" do
    it "returns nil for unregistered element class" do
      expect(library[Markbridge::AST::Bold]).to be_nil
    end

    it "returns tag for registered element class" do
      tag = Markbridge::Renderers::Discourse::Tag.new { "test" }
      library.register(Markbridge::AST::Bold, tag)

      expect(library[Markbridge::AST::Bold]).to eq(tag)
    end
  end

  describe "#resolve" do
    let(:tag) { Markbridge::Renderers::Discourse::Tag.new { |_, _| "x" } }

    it "returns the tag of the nearest ancestor with a registered tag" do
      library.register(Markbridge::AST::Bold, tag)
      subclass = Class.new(Markbridge::AST::Bold)

      expect(library.resolve(subclass)).to be(tag)
    end

    it "prefers the nearest ancestor when several ancestors have tags" do
      middle_tag = Markbridge::Renderers::Discourse::Tag.new { |_, _| "m" }
      middle = Class.new(Markbridge::AST::Bold)
      leaf = Class.new(middle)
      library.register(Markbridge::AST::Bold, tag)
      library.register(middle, middle_tag)

      expect(library.resolve(leaf)).to be(middle_tag)
    end

    it "skips the exact class itself — that lookup is #[]" do
      library.register(Markbridge::AST::Bold, tag)

      expect(library.resolve(Markbridge::AST::Bold)).to be_nil
    end

    it "returns nil when no ancestor has a tag" do
      expect(library.resolve(Class.new(Markbridge::AST::Bold))).to be_nil
    end

    it "finds a tag registered for AST::Node, the top of the walk" do
      library.register(Markbridge::AST::Node, tag)

      expect(library.resolve(Markbridge::AST::Bold)).to be(tag)
    end

    it "never walks outside the AST hierarchy" do
      library.register(Object, tag)

      expect(library.resolve(Markbridge::AST::Bold)).to be_nil
    end

    it "returns nil for a class without a superclass" do
      expect(library.resolve(BasicObject)).to be_nil
    end
  end

  describe ".default" do
    let(:default_library) { described_class.default }

    it "returns a TagLibrary" do
      expect(default_library).to be_a(described_class)
    end

    it "registers no tag for AST::Element or AST::Node" do
      # Ancestry dispatch and the unregister-for-passthrough idiom both
      # count on this: with a tag on Element or Node, every unregistered
      # element class would suddenly inherit it.
      expect(default_library[Markbridge::AST::Element]).to be_nil
      expect(default_library[Markbridge::AST::Node]).to be_nil
    end

    Markbridge::Renderers::Discourse::Tags.constants.each do |const_name|
      tag_class = Markbridge::Renderers::Discourse::Tags.const_get(const_name)
      next unless tag_class.is_a?(Class) && tag_class < Markbridge::Renderers::Discourse::Tag
      element_name = const_name.to_s.sub(/Tag$/, "")
      element_class =
        begin
          Markbridge::AST.const_get(element_name)
        rescue StandardError
          nil
        end
      next unless element_class

      it "registers #{tag_class.name.split("::").last} for #{element_class.name.split("::").last}" do
        expect(default_library[element_class]).to be_a(tag_class)
      end
    end

    it "renders bold correctly" do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("text")

      tag = default_library[Markbridge::AST::Bold]
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      result = tag.render(bold, interface)

      expect(result).to eq("**text**")
    end

    it "renders italic correctly" do
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("text")

      tag = default_library[Markbridge::AST::Italic]
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      result = tag.render(italic, interface)

      expect(result).to eq("*text*")
    end
  end

  describe "#each" do
    it "yields registered (element_class, tag) pairs" do
      bold_tag = Markbridge::Renderers::Discourse::Tag.new { "b" }
      italic_tag = Markbridge::Renderers::Discourse::Tag.new { "i" }
      library.register(Markbridge::AST::Bold, bold_tag)
      library.register(Markbridge::AST::Italic, italic_tag)

      expect(library.to_a).to eq(
        [[Markbridge::AST::Bold, bold_tag], [Markbridge::AST::Italic, italic_tag]],
      )
    end

    it "returns an Enumerator when no block is given" do
      expect(library.each).to be_a(Enumerator)
    end

    it "yields nothing on an empty library" do
      yielded = []
      library.each { |pair| yielded << pair }

      expect(yielded).to be_empty
    end

    it "exposes Enumerable conveniences (count, to_h)" do
      tag = Markbridge::Renderers::Discourse::Tag.new { "b" }
      library.register(Markbridge::AST::Bold, tag)

      expect(library.count).to eq(1)
      expect(library.to_h).to eq({ Markbridge::AST::Bold => tag })
    end
  end

  describe "#ast_class_for" do
    it "returns the matching AST class via the XxxTag → AST::Xxx convention" do
      expect(library.ast_class_for(:BoldTag)).to eq(Markbridge::AST::Bold)
    end

    it "returns nil when no matching AST class exists" do
      expect(library.ast_class_for(:NonexistentXyzTag)).to be_nil
    end
  end

  describe "#auto_register!" do
    it "registers all tag classes" do
      library.auto_register!

      # Should register tags following the naming convention
      expect(library[Markbridge::AST::Bold]).to be_a(
        Markbridge::Renderers::Discourse::Tags::BoldTag,
      )
      expect(library[Markbridge::AST::Italic]).to be_a(
        Markbridge::Renderers::Discourse::Tags::ItalicTag,
      )
      expect(library[Markbridge::AST::Code]).to be_a(
        Markbridge::Renderers::Discourse::Tags::CodeTag,
      )
    end

    it "creates new instances for each tag" do
      library.auto_register!

      tag1 = library[Markbridge::AST::Bold]
      tag2 = library[Markbridge::AST::Bold]

      # Same class, but will be the same instance since we only register once
      expect(tag1).to eq(tag2)
    end

    it "returns self for chaining" do
      result = library.auto_register!
      expect(result).to eq(library)
    end

    it "skips tags whose name does not have a matching AST element class" do
      # Inject a Tag subclass whose name doesn't map to any AST class.
      orphan = Class.new(Markbridge::Renderers::Discourse::Tag)
      Markbridge::Renderers::Discourse::Tags.const_set(:NonexistentXyzTag, orphan)

      begin
        # Without the guard, `register(nil, ...)` would be called and the nil key
        # would later overwrite a real lookup via `library[nil]`. Verify the
        # orphan is silently skipped.
        library.auto_register!

        expect(library[nil]).to be_nil
      ensure
        Markbridge::Renderers::Discourse::Tags.send(:remove_const, :NonexistentXyzTag)
      end
    end
  end

  describe "#unregister" do
    it "removes a previously registered binding" do
      tag = Markbridge::Renderers::Discourse::Tag.new { |_, _| "x" }
      library.register(Markbridge::AST::Bold, tag)

      library.unregister(Markbridge::AST::Bold)

      expect(library[Markbridge::AST::Bold]).to be_nil
    end

    it "is a no-op when the class was never registered" do
      expect { library.unregister(Markbridge::AST::Bold) }.not_to raise_error
    end

    it "returns self for chaining" do
      expect(library.unregister(Markbridge::AST::Bold)).to be(library)
    end
  end

  describe "#merge!" do
    let(:bold_tag) { Markbridge::Renderers::Discourse::Tag.new { |_, _| "b" } }
    let(:italic_tag) { Markbridge::Renderers::Discourse::Tag.new { |_, _| "i" } }

    it "registers each non-nil mapping" do
      library.merge!(Markbridge::AST::Bold => bold_tag, Markbridge::AST::Italic => italic_tag)

      expect(library[Markbridge::AST::Bold]).to be(bold_tag)
      expect(library[Markbridge::AST::Italic]).to be(italic_tag)
    end

    it "unregisters classes with a nil value" do
      library.register(Markbridge::AST::Bold, bold_tag)

      library.merge!(Markbridge::AST::Bold => nil)

      expect(library[Markbridge::AST::Bold]).to be_nil
    end

    it "removes the class from iteration when given a nil value (vs. registering nil)" do
      library.register(Markbridge::AST::Bold, bold_tag)

      library.merge!(Markbridge::AST::Bold => nil)

      # Iteration must reflect deletion — registering `nil` would leave the
      # class as a key with a nil value.
      expect(library.map { |klass, _| klass }).not_to include(Markbridge::AST::Bold)
    end

    it "returns self for chaining" do
      expect(library.merge!({})).to be(library)
    end
  end

  describe "#dup" do
    let(:tag) { Markbridge::Renderers::Discourse::Tag.new { |_, _| "x" } }

    it "isolates the @tags Hash so mutations on the copy don't leak back" do
      # Ruby's default Object#dup is a shallow copy — both copies would
      # share the same @tags Hash and mutations would leak both ways.
      # TagLibrary#initialize_copy exists specifically to break that.
      original = described_class.new
      original.register(Markbridge::AST::Bold, tag)

      copy = original.dup
      copy.register(Markbridge::AST::Italic, tag)
      copy.unregister(Markbridge::AST::Bold)

      expect(original[Markbridge::AST::Bold]).to be(tag)
      expect(original[Markbridge::AST::Italic]).to be_nil
    end

    it "produces a copy with the same initial bindings" do
      original = described_class.new
      original.register(Markbridge::AST::Bold, tag)

      expect(original.dup[Markbridge::AST::Bold]).to be(tag)
    end
  end

  describe ".shared_default" do
    it "returns the same instance on every call" do
      expect(described_class.shared_default).to be(described_class.shared_default)
    end

    it "is frozen" do
      expect(described_class.shared_default).to be_frozen
    end

    it "resolves the default tags" do
      expect(described_class.shared_default[Markbridge::AST::Bold]).to be_a(
        Markbridge::Renderers::Discourse::Tags::BoldTag,
      )
    end

    it "is a different instance from .default" do
      expect(described_class.shared_default).not_to be(described_class.default)
    end

    it "dups into a mutable, isolated copy" do
      copy = described_class.shared_default.dup
      copy.unregister(Markbridge::AST::Bold)

      expect(copy[Markbridge::AST::Bold]).to be_nil
      expect(described_class.shared_default[Markbridge::AST::Bold]).not_to be_nil
    end
  end

  describe "#freeze" do
    let(:tag) { Markbridge::Renderers::Discourse::Tag.new { |_, _| "x" } }

    it "makes register raise instead of silently mutating shared state" do
      frozen = described_class.new.freeze

      expect { frozen.register(Markbridge::AST::Bold, tag) }.to raise_error(FrozenError)
    end

    it "returns self" do
      library = described_class.new

      expect(library.freeze).to be(library)
    end

    it "flattens inherited tags into exact bindings for known subclasses" do
      subclass = Class.new(Markbridge::AST::Bold)
      library.register(Markbridge::AST::Bold, tag)

      library.freeze

      # The exact-class lookup now hits directly — no ancestry walk left.
      expect(library[subclass]).to be(tag)
    end

    it "prefers the nearest ancestor when flattening" do
      middle_tag = Markbridge::Renderers::Discourse::Tag.new { |_, _| "m" }
      middle = Class.new(Markbridge::AST::Bold)
      leaf = Class.new(middle)
      library.register(Markbridge::AST::Bold, tag)
      library.register(middle, middle_tag)

      library.freeze

      expect(library[leaf]).to be(middle_tag)
    end

    it "adds no binding for classes whose ancestry resolves to no tag" do
      subclass = Class.new(Markbridge::AST::Element)
      library.register(Markbridge::AST::Bold, tag)

      library.freeze

      expect(library[subclass]).to be_nil
      expect(library[Markbridge::AST::Text]).to be_nil
      # Not even a nil binding — the class must stay absent from the
      # internal Hash, or iteration and key checks would report it.
      expect(library.map { |klass, _| klass }).not_to include(subclass, Markbridge::AST::Text)
    end

    it "leaves explicit bindings alone" do
      subclass = Class.new(Markbridge::AST::Bold)
      own_tag = Markbridge::Renderers::Discourse::Tag.new { |_, _| "own" }
      library.register(Markbridge::AST::Bold, tag)
      library.register(subclass, own_tag)

      library.freeze

      expect(library[subclass]).to be(own_tag)
    end
  end

  describe "#dup of a frozen library" do
    let(:tag) { Markbridge::Renderers::Discourse::Tag.new { |_, _| "x" } }

    it "drops the flattened entries so the copy goes back to lazy resolution" do
      subclass = Class.new(Markbridge::AST::Bold)
      library.register(Markbridge::AST::Bold, tag)
      library.freeze
      expect(library[subclass]).to be(tag) # flattened

      copy = library.dup

      # The copy is mutable; a later register on the base class must win
      # again, so no baked-in entry may remain.
      expect(copy[subclass]).to be_nil
      expect(copy.resolve(subclass)).to be(tag)
      expect(copy[Markbridge::AST::Bold]).to be(tag)
    end

    it "lets a base class override on the copy reach known subclasses again" do
      subclass = Class.new(Markbridge::AST::Bold)
      library.register(Markbridge::AST::Bold, tag)
      library.freeze

      copy = library.dup
      other = Markbridge::Renderers::Discourse::Tag.new { |_, _| "other" }
      copy.register(Markbridge::AST::Bold, other)

      expect(copy.resolve(subclass)).to be(other)
    end
  end
end
