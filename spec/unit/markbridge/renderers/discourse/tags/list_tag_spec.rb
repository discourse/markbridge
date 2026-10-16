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

    it "renders a list without items to nothing" do
      context = Markbridge::Renderers::Discourse::RenderContext.new
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)

      expect(tag.render(list, interface)).to eq("")
    end

    it "renders a list whose items are all empty to nothing" do
      context = Markbridge::Renderers::Discourse::RenderContext.new
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)
      list << Markbridge::AST::ListItem.new

      expect(tag.render(list, interface)).to eq("")
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
      # One blank line after the list, so text that follows it in the
      # same item starts its own paragraph.
      expect(result).to end_with("- nested item\n\n")
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

      expect(result).to eq("\n- inner\n\n")
    end

    it "treats a list inside a ListItem subclass as nested" do
      item_class = Class.new(Markbridge::AST::ListItem)
      context = Markbridge::Renderers::Discourse::RenderContext.new([item_class.new])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("inner")
      list << item

      expect(tag.render(list, interface)).to eq("\n- inner\n\n")
    end

    it "treats a list inside a List subclass as nested" do
      list_class = Class.new(Markbridge::AST::List)
      context = Markbridge::Renderers::Discourse::RenderContext.new([list_class.new])
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("inner")
      list << item

      expect(tag.render(list, interface)).to eq("\n- inner\n\n")
    end

    it "treats a list inside a quote inside a list item as a block" do
      quote = Markbridge::AST::Quote.new
      context =
        Markbridge::Renderers::Discourse::RenderContext.new(
          [Markbridge::AST::List.new, Markbridge::AST::ListItem.new, quote],
        )
      interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("inner")
      list << item

      # Only the direct parent counts. Text after the list inside the
      # quote would otherwise continue the last item.
      expect(tag.render(list, interface)).to eq("\n\n- inner\n\n\n")
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

      # A nested item does not indent itself; the item that holds the
      # nested list indents its whole content.
      expect(tag.render(inner_list, interface)).to eq("\n- nested\n\n")
    end

    context "with a list of the same kind in front of it" do
      def list_with_item(ordered:, text:)
        list = Markbridge::AST::List.new(ordered:)
        item = Markbridge::AST::ListItem.new
        item << Markbridge::AST::Text.new(text)
        list << item
      end

      # Renders +list+ as a child of a document that holds +siblings+ in
      # order, so the tag can see what stands in front of it.
      def render_in_document(list, *siblings)
        document = Markbridge::AST::Document.new
        siblings.each { |sibling| document << sibling }
        context = Markbridge::Renderers::Discourse::RenderContext.new([document])
        tag.render(
          list,
          Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context),
        )
      end

      it "puts a comment between blank lines in front of the list" do
        first = list_with_item(ordered: false, text: "a")
        second = list_with_item(ordered: false, text: "b")

        expect(render_in_document(second, first, second)).to eq("\n\n<!---->\n\n\n\n- b\n\n\n")
      end

      it "separates two ordered lists" do
        first = list_with_item(ordered: true, text: "a")
        second = list_with_item(ordered: true, text: "b")

        expect(render_in_document(second, first, second)).to start_with("\n\n<!---->")
      end

      it "separates two lists whose classes are subclasses of List" do
        list_class = Class.new(Markbridge::AST::List)
        first = list_class.new(ordered: false)
        first << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a"))
        second = list_class.new(ordered: false)
        second << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("b"))

        expect(render_in_document(second, first, second)).to start_with("\n\n<!---->")
      end

      it "does not separate an ordered list from an unordered one" do
        # A change of list kind starts a new list on its own.
        first = list_with_item(ordered: false, text: "a")
        second = list_with_item(ordered: true, text: "b")

        expect(render_in_document(second, first, second)).to eq("\n\n1. b\n\n\n")
      end

      it "does not separate a list from text in front of it" do
        list = list_with_item(ordered: false, text: "a")

        expect(render_in_document(list, Markbridge::AST::Text.new("before"), list)).to eq(
          "\n\n- a\n\n\n",
        )
      end

      it "does not separate the first list in the document" do
        list = list_with_item(ordered: false, text: "a")

        expect(render_in_document(list, list)).to eq("\n\n- a\n\n\n")
      end

      it "does not separate a list whose parent is not known" do
        list = list_with_item(ordered: false, text: "a")
        context = Markbridge::Renderers::Discourse::RenderContext.new
        interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

        expect(tag.render(list, interface)).to eq("\n\n- a\n\n\n")
      end
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }
      let(:interface) do
        Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
      end

      it "renders an unordered list as <ul>" do
        list = Markbridge::AST::List.new(ordered: false)
        item = Markbridge::AST::ListItem.new
        item << Markbridge::AST::Text.new("item")
        list << item

        expect(tag.render(list, interface)).to eq("<ul><li>item</li></ul>")
      end

      it "renders an ordered list as <ol>" do
        list = Markbridge::AST::List.new(ordered: true)
        item = Markbridge::AST::ListItem.new
        item << Markbridge::AST::Text.new("item")
        list << item

        expect(tag.render(list, interface)).to eq("<ol><li>item</li></ol>")
      end

      it "renders nested lists" do
        outer = Markbridge::AST::List.new(ordered: false)
        outer_item = Markbridge::AST::ListItem.new
        outer_item << Markbridge::AST::Text.new("a")
        inner = Markbridge::AST::List.new(ordered: false)
        inner_item = Markbridge::AST::ListItem.new
        inner_item << Markbridge::AST::Text.new("b")
        inner << inner_item
        outer_item << inner
        outer << outer_item

        expect(tag.render(outer, interface)).to eq("<ul><li>a<ul><li>b</li></ul></li></ul>")
      end
    end
  end
end
