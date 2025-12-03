# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ListTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }

  describe "#render" do
    it "wraps list content with blank lines at top level" do
      context = Markbridge::Renderers::Discourse::RenderContext.new
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("item")
      list << item

      result = tag.render(list, interface)

      expect(result).to start_with("\n\n")
      expect(result).to end_with("\n\n")
      expect(result).to include("- item")
    end

    it "passes list in context to children" do
      context = Markbridge::Renderers::Discourse::RenderContext.new
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: true)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("item")
      list << item

      result = tag.render(list, interface)

      # Should render as ordered because list is in context
      expect(result).to include("1. item")
    end

    it "doesn't add extra newlines for nested lists" do
      outer_list = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([outer_list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      inner_list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("nested item")
      inner_list << item

      result = tag.render(inner_list, interface)

      expect(result).to start_with("\n")
      expect(result).not_to start_with("\n\n")
      expect(result).not_to end_with("\n\n")
    end

    it "handles document as parent in context" do
      document = Markbridge::AST::Document.new
      context = Markbridge::Renderers::Discourse::RenderContext.new([document])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("item")
      list << item

      result = tag.render(list, interface)

      expect(result).to start_with("\n\n")
      expect(result).to end_with("\n\n")
    end

    it "creates new context for children" do
      context = Markbridge::Renderers::Discourse::RenderContext.new
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)

      # Verify context is immutable - original unchanged
      tag.render(list, interface)

      expect(context.parents).to eq([])
    end
  end
end
