# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ListItemTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }

  describe "#render" do
    it "renders unordered list item with dash" do
      list = Markbridge::AST::List.new(ordered: false)
      # When list renders an item, item sees the list in context
      context = Markbridge::Renderers::Discourse::RenderContext.new([list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("item text")

      result = tag.render(item, interface)
      # 1 list in context (direct parent) → no indent
      expect(result).to eq("- item text\n")
    end

    it "renders ordered list item with number" do
      list = Markbridge::AST::List.new(ordered: true)
      context = Markbridge::Renderers::Discourse::RenderContext.new([list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("item text")

      result = tag.render(item, interface)
      expect(result).to eq("1. item text\n")
    end

    it "handles multi-line items with indentation" do
      list = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("line1\nline2")

      result = tag.render(item, interface)
      expect(result).to eq("- line1\n  line2\n")
    end

    it "preserves blank lines in multi-paragraph list items" do
      list = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("First paragraph\n\nSecond paragraph")

      result = tag.render(item, interface)
      expect(result).to eq("- First paragraph\n  \n  Second paragraph\n")
    end

    it "strips whitespace from content" do
      list = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("  item text  ")

      result = tag.render(item, interface)
      expect(result).to eq("- item text\n")
    end

    it "indents nested list items" do
      outer_list = Markbridge::AST::List.new(ordered: false)
      inner_list = Markbridge::AST::List.new(ordered: false)
      # 2 lists: outer is ancestor, inner is direct parent
      context = Markbridge::Renderers::Discourse::RenderContext.new([outer_list, inner_list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("nested item")

      result = tag.render(item, interface)
      # 2 lists - 1 = 1 ancestor → 2 spaces indent
      expect(result).to eq("  - nested item\n")
    end

    it "indents multi-line nested list items" do
      outer_list = Markbridge::AST::List.new(ordered: false)
      inner_list = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([outer_list, inner_list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("line1\nline2")

      result = tag.render(item, interface)
      # 2 lists - 1 = 2 spaces for item, 4 spaces for continuation
      expect(result).to eq("  - line1\n    line2\n")
    end

    it "handles deeply nested items" do
      list1 = Markbridge::AST::List.new(ordered: false)
      list2 = Markbridge::AST::List.new(ordered: true)
      list3 = Markbridge::AST::List.new(ordered: false)
      # 3 lists: 2 ancestors, 1 direct parent
      context = Markbridge::Renderers::Discourse::RenderContext.new([list1, list2, list3])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("deep item")

      result = tag.render(item, interface)
      # 3 lists - 1 = 2 ancestors
      # Indent: list1 (unordered=2 spaces) + list2 (ordered=3 spaces) = 5 spaces
      expect(result).to eq("     - deep item\n")
    end

    it "ignores non-List parents in the chain when counting indent" do
      # Kills `unless parent.instance_of?(AST::List)` → `unless true` /
      # `unless AST::List` / drop-unless. With those mutations, the
      # loop would call `.ordered?` on non-List parents (Document,
      # Paragraph, ListItem, ...), raising NoMethodError.
      doc = Markbridge::AST::Document.new
      list1 = Markbridge::AST::List.new(ordered: false)
      paragraph = Markbridge::AST::Paragraph.new # interloper, not a List
      list2 = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([doc, list1, paragraph, list2])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("nested")

      # 2 Lists in chain → 1 ancestor (list1, unordered = 2 spaces).
      result = tag.render(item, interface)
      expect(result).to eq("  - nested\n")
    end

    it "works without parent list (edge case)" do
      context = Markbridge::Renderers::Discourse::RenderContext.new
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("orphan item")

      result = tag.render(item, interface)
      # 0 lists → no indent
      expect(result).to eq("- orphan item\n")
    end

    # Kills mutations that drop the `if content.empty?` guard or the
    # early `return ""`. An empty ListItem has no children, so
    # render_children produces ""; without the guard the builder
    # would emit `"- \n"`.
    it "returns empty string for a ListItem with no content" do
      list = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new

      expect(tag.render(item, interface)).to eq("")
    end

    # Kills the `interface.with_parent(element)` → `interface` /
    # `interface.with_parent(nil)` mutations. A nested list inside a
    # list item must see the outer ListItem in its parent chain so
    # ListTag#render treats it as a nested list (single \n wrapping
    # vs double \n\n). Pre-existing tests only nest via the
    # RenderContext, not via a real ListItem child.
    it "adds the current ListItem to the parent chain for children" do
      outer_list = Markbridge::AST::List.new(ordered: false)
      context = Markbridge::Renderers::Discourse::RenderContext.new([outer_list])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

      item = Markbridge::AST::ListItem.new
      nested_list = Markbridge::AST::List.new(ordered: false)
      nested_item = Markbridge::AST::ListItem.new
      nested_item << Markbridge::AST::Text.new("nested")
      nested_list << nested_item
      item << nested_list

      result = tag.render(item, interface)

      # The nested list, seeing ListItem in its parent chain, must
      # render with nested-style single-\n wrapping, not top-level \n\n.
      expect(result).not_to include("\n\n")
      expect(result).to include("- nested")
    end
  end
end
