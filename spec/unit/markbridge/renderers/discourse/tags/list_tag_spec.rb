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

    # Strict equality — the start_with/include checks above pass even
    # under mutations that swap `content` for nil or `join` for
    # identity-return. Lock in the exact output shape for a known list.
    it "renders a single-item top-level list to the exact expected string" do
      context = Markbridge::Renderers::Discourse::RenderContext.new
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("item")
      list << item

      expect(tag.render(list, interface)).to eq("\n\n- item\n\n\n")
    end

    # Kills the `rendered_items.join` → `rendered_items` mutation. With a
    # single item, Array interpolation and String interpolation both look
    # similar enough to slip past include() checks; two items make the
    # Array#to_s shape visible.
    it "joins multiple items without Array inspect delimiters" do
      context = Markbridge::Renderers::Discourse::RenderContext.new
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)
      2.times do |i|
        item = Markbridge::AST::ListItem.new
        item << Markbridge::AST::Text.new("item#{i}")
        list << item
      end

      result = tag.render(list, interface)

      expect(result).not_to include("[")
      expect(result).not_to include("]")
      expect(result).not_to include('\"')
    end

    # Kills mutations that make `has_list_item_parent` always false
    # (`= false`, `= nil`, `has_parent?(nil)`), and the `||` drop on
    # `nested = has_list_parent || has_list_item_parent`. Context has
    # ListItem but NOT List; only the ListItem-aware branch fires.
    it "treats a list nested inside a ListItem (but not a List) as nested" do
      parent_item = Markbridge::AST::ListItem.new
      context = Markbridge::Renderers::Discourse::RenderContext.new([parent_item])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("inner")
      list << item

      result = tag.render(list, interface)

      expect(result).to start_with("\n")
      expect(result).not_to start_with("\n\n")
      expect(result).not_to end_with("\n\n")
      # Content must be present (kills `"\n#{content}"` → `"\n#{nil}"`)
      expect(result).to include("- inner")
    end

    # Same identity tightening for the nested branch: kills mutations on
    # `"\n#{content}"` that replace content with nil, and on `join` (for
    # the same reason as the top-level multi-item test).
    it "renders a nested list to exactly `\\n` + joined-items" do
      outer_list = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([outer_list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      inner_list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("nested")
      inner_list << item

      # Outer list adds 2-space indent to inner items.
      expect(tag.render(inner_list, interface)).to eq("\n  - nested\n")
    end
  end
end
