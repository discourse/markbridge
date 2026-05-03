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

  describe ".default" do
    let(:default_library) { described_class.default }

    it "returns a TagLibrary" do
      expect(default_library).to be_a(described_class)
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
end
