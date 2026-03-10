# frozen_string_literal: true

RSpec.describe "BBCode Auto-Closing Behavior" do
  let(:parser) { Markbridge::Parsers::BBCode::Parser.new }

  describe "list item auto-closing" do
    it "auto-closes previous list item when opening a new one" do
      result = parser.parse("[list][*]Item 1[*]Item 2[/list]")
      list = result.children.first

      expect(list).to be_a(Markbridge::AST::List)
      expect(list.children.size).to eq(2)
      expect(list.children).to all(be_a(Markbridge::AST::ListItem))

      # Verify each item has its content
      expect(list.children[0].children.first.text).to eq("Item 1")
      expect(list.children[1].children.first.text).to eq("Item 2")
    end

    it "auto-closes list item with nested content" do
      result = parser.parse("[list][*][b]Bold[/b] text[*]Item 2[/list]")
      list = result.children.first

      first_item = list.children[0]
      expect(first_item.children.size).to eq(2)
      expect(first_item.children[0]).to be_a(Markbridge::AST::Bold)
      expect(first_item.children[1].text).to eq(" text")
    end

    it "auto-closes multiple consecutive list items" do
      result = parser.parse("[list][*]One[*]Two[*]Three[*]Four[/list]")
      list = result.children.first

      expect(list.children.size).to eq(4)
      expect(list.children.map { |item| item.children.first.text }).to eq(%w[One Two Three Four])
    end

    it "handles explicit list item closing tags" do
      result = parser.parse("[list][*]Item 1[/li][*]Item 2[/li][/list]")
      list = result.children.first

      expect(list.children.size).to eq(2)
      expect(list.children).to all(be_a(Markbridge::AST::ListItem))
    end

    it "handles mixed explicit and implicit list item closing" do
      result = parser.parse("[list][*]Item 1[/li][*]Item 2[*]Item 3[/li][/list]")
      list = result.children.first

      expect(list.children.size).to eq(3)
    end
  end

  describe "list auto-closing of items" do
    it "auto-closes open list item when list closes" do
      result = parser.parse("[list][*]Item 1[/list]")
      list = result.children.first

      expect(list.children.size).to eq(1)
      expect(list.children.first).to be_a(Markbridge::AST::ListItem)
      expect(list.children.first.children.first.text).to eq("Item 1")
    end

    it "auto-closes last item with nested tags" do
      result = parser.parse("[list][*]Item 1[*][b]Bold item[/b][/list]")
      list = result.children.first

      second_item = list.children[1]
      expect(second_item.children.first).to be_a(Markbridge::AST::Bold)
    end

    it "auto-closes item when list closes after multiple items" do
      result = parser.parse("[list][*]One[*]Two[*]Three[/list]")
      list = result.children.first

      expect(list.children.size).to eq(3)
      # All items should be properly closed
      list.children.each { |item| expect(item).to be_a(Markbridge::AST::ListItem) }
    end
  end

  describe "nested list auto-closing" do
    it "auto-closes nested list items correctly" do
      result = parser.parse("[list][*]Outer 1[list][*]Inner 1[*]Inner 2[/list][*]Outer 2[/list]")
      outer_list = result.children.first

      expect(outer_list.children.size).to eq(2)

      first_outer_item = outer_list.children[0]
      # First outer item should contain text "Outer 1" and a nested list
      expect(first_outer_item.children.size).to eq(2)
      expect(first_outer_item.children[0].text).to eq("Outer 1")

      inner_list = first_outer_item.children[1]
      expect(inner_list).to be_a(Markbridge::AST::List)
      expect(inner_list.children.size).to eq(2)
    end

    it "auto-closes multiple levels of nesting" do
      result = parser.parse("[list][*]L1[list][*]L2[list][*]L3[/list][/list][/list]")
      l1_list = result.children.first
      l1_item = l1_list.children.first

      l2_list = l1_item.children[1]
      expect(l2_list).to be_a(Markbridge::AST::List)

      l2_item = l2_list.children.first
      l3_list = l2_item.children[1]
      expect(l3_list).to be_a(Markbridge::AST::List)
    end

    it "handles nested lists with multiple items at each level" do
      result = parser.parse("[list][*]A[*]B[list][*]B1[*]B2[/list][*]C[/list]")
      outer_list = result.children.first

      expect(outer_list.children.size).to eq(3)

      second_item = outer_list.children[1]
      nested_list = second_item.children[1]
      expect(nested_list).to be_a(Markbridge::AST::List)
      expect(nested_list.children.size).to eq(2)
    end
  end

  describe "edge cases in auto-closing" do
    it "handles empty list items" do
      result = parser.parse("[list][*][*]Item 2[/list]")
      list = result.children.first

      expect(list.children.size).to eq(2)
      expect(list.children[0].children).to be_empty
      expect(list.children[1].children.first.text).to eq("Item 2")
    end

    it "handles list item with only whitespace" do
      result = parser.parse("[list][*]   [*]Item 2[/list]")
      list = result.children.first

      expect(list.children.size).to eq(2)
      expect(list.children[0].children.first.text).to eq("   ")
    end

    it "handles consecutive opening tags correctly" do
      result = parser.parse("[list][*][b]Bold[/b][*]Next[/list]")
      list = result.children.first

      expect(list.children.size).to eq(2)
      expect(list.children[0].children.first).to be_a(Markbridge::AST::Bold)
    end
  end

  describe "integration with handlers and registry" do
    it "uses correct handler for auto-closing" do
      # This test verifies that the handler registry properly routes
      # auto-closing behavior through the right handlers
      result = parser.parse("[list][*]Item[/list]")
      list = result.children.first

      # The ListHandler's on_close should have auto-closed the list item
      expect(list.children.size).to eq(1)
      expect(list.children.first).to be_a(Markbridge::AST::ListItem)
    end

    it "maintains context stack properly during auto-closing" do
      result = parser.parse("[b][list][*]Item[/list][/b]")
      bold = result.children.first
      list = bold.children.first

      # Both bold and list should be properly closed
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.children.first).to be_a(Markbridge::AST::ListItem)
    end

    it "handles auto-closing with multiple handler types" do
      result = parser.parse("[list][*][b]Bold[/b][i]Italic[/i][*]Next[/list]")
      list = result.children.first
      first_item = list.children[0]

      expect(first_item.children.size).to eq(2)
      expect(first_item.children[0]).to be_a(Markbridge::AST::Bold)
      expect(first_item.children[1]).to be_a(Markbridge::AST::Italic)
    end
  end

  describe "color and size auto-closing across structural boundaries" do
    it "auto-closes color when list closes inside color" do
      result = parser.parse("[color=green][b]Title[/b]\n[list][*]Item 1[*]Item 2[/list][/color]")
      color = result.children.first

      expect(color).to be_a(Markbridge::AST::Color)
      expect(color.children.size).to eq(3)
      expect(color.children[0]).to be_a(Markbridge::AST::Bold)
      expect(color.children[2]).to be_a(Markbridge::AST::List)
    end

    it "auto-closes size when list closes inside size" do
      result = parser.parse("[size=150][b]Title[/b]\n[list][*]Item 1[/list][/size]")
      size = result.children.first

      expect(size).to be_a(Markbridge::AST::Size)
      expect(size.children[0]).to be_a(Markbridge::AST::Bold)
    end

    it "does not leak closing color tag as text" do
      result = parser.parse("[list][color=red][b]Skill[/b]\nLevel 2\nLevel 3[/color][/list]")

      # No Text node with "[/color]" should exist anywhere in the tree
      all_text = collect_text_nodes(result)
      expect(all_text).not_to include("[/color]")
    end

    it "does not leak closing size tag as text" do
      result = parser.parse("[list][size=20][b]Skill[/b]\nLevel 2[/size][/list]")

      all_text = collect_text_nodes(result)
      expect(all_text).not_to include("[/size]")
    end

    it "handles color wrapping nested lists" do
      result =
        parser.parse(
          "[list][color=green][b]Skill[/b]\n[list]Level 2\nLevel 3[/list][/color][/list]",
        )
      outer_list = result.children.first

      expect(outer_list).to be_a(Markbridge::AST::List)
      # No Text node with leaked tags
      all_text = collect_text_nodes(result)
      expect(all_text).not_to include("[/color]")
      expect(all_text).not_to include("[/list]")
    end
  end

  # Helper to recursively collect all Text node contents
  def collect_text_nodes(node)
    texts = []
    texts << node.text if node.is_a?(Markbridge::AST::Text)
    if node.respond_to?(:children)
      node.children.each { |child| texts.concat(collect_text_nodes(child)) }
    end
    texts
  end
end
