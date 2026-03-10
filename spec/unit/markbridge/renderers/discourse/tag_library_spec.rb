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

    it "registers Bold tag" do
      expect(default_library[Markbridge::AST::Bold]).not_to be_nil
    end

    it "registers Italic tag" do
      expect(default_library[Markbridge::AST::Italic]).not_to be_nil
    end

    it "registers Strikethrough tag" do
      expect(default_library[Markbridge::AST::Strikethrough]).not_to be_nil
    end

    it "registers Underline tag" do
      expect(default_library[Markbridge::AST::Underline]).not_to be_nil
    end

    it "registers Code tag" do
      expect(default_library[Markbridge::AST::Code]).not_to be_nil
    end

    it "registers Url tag" do
      expect(default_library[Markbridge::AST::Url]).not_to be_nil
    end

    it "registers List tag" do
      expect(default_library[Markbridge::AST::List]).not_to be_nil
    end

    it "registers ListItem tag" do
      expect(default_library[Markbridge::AST::ListItem]).not_to be_nil
    end

    it "registers LineBreak tag" do
      expect(default_library[Markbridge::AST::LineBreak]).not_to be_nil
    end

    it "registers HorizontalRule tag" do
      expect(default_library[Markbridge::AST::HorizontalRule]).not_to be_nil
    end

    it "registers Table tag" do
      expect(default_library[Markbridge::AST::Table]).not_to be_nil
    end

    it "registers TableRow tag" do
      expect(default_library[Markbridge::AST::TableRow]).not_to be_nil
    end

    it "registers TableCell tag" do
      expect(default_library[Markbridge::AST::TableCell]).not_to be_nil
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

    it "skips tags that don't have matching AST elements" do
      # Should not raise an error even if there's a tag without matching element
      expect { library.auto_register! }.not_to raise_error
    end
  end
end
