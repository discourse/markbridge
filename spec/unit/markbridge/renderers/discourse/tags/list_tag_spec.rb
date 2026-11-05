# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ListTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "renders a list without items to nothing" do
      list = Markbridge::AST::List.new(ordered: false)

      expect(tag.render(list, interface)).to eq("")
    end

    it "renders a list whose items are all empty to nothing" do
      list = Markbridge::AST::List.new(ordered: false)
      list << Markbridge::AST::ListItem.new

      expect(tag.render(list, interface)).to eq("")
    end

    it "leaves the context it renders in alone" do
      list = Markbridge::AST::List.new(ordered: false)

      tag.render(list, interface)

      expect(context.parents).to eq([])
    end

    it "renders a list at the top level between blank lines" do
      list = Markbridge::AST::List.new(ordered: false)
      item = Markbridge::AST::ListItem.new
      item << Markbridge::AST::Text.new("item")
      list << item

      expect(tag.render(list, interface)).to eq("\n\n- item\n\n\n")
    end

    it "renders an ordered list with its own marker" do
      list = Markbridge::AST::List.new(ordered: true)
      list << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("item"))

      expect(tag.render(list, interface)).to eq("\n\n1. item\n\n\n")
    end

    it "joins the items one after the other" do
      list = Markbridge::AST::List.new(ordered: false)
      2.times do |i|
        item = Markbridge::AST::ListItem.new
        item << Markbridge::AST::Text.new("item#{i}")
        list << item
      end

      expect(tag.render(list, interface)).to eq("\n\n- item0\n- item1\n\n\n")
    end

    it "treats a list under a list, a list item, or a subclass of either as nested" do
      # Only the direct parent counts, and a nested list gets no blank
      # lines: they would make the outer list loose.
      parents = [
        Markbridge::AST::List.new,
        Markbridge::AST::ListItem.new,
        Class.new(Markbridge::AST::List).new,
        Class.new(Markbridge::AST::ListItem).new,
      ]

      parents.each do |parent|
        list = Markbridge::AST::List.new(ordered: false)
        list << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("inner"))

        expect(tag.render(list, interface_for(parent))).to eq("\n- inner\n"), parent.class.inspect
      end
    end

    it "treats a list inside a quote inside a list item as a block" do
      quote = Markbridge::AST::Quote.new
      parents = [Markbridge::AST::List.new, Markbridge::AST::ListItem.new, quote]
      list = Markbridge::AST::List.new(ordered: false)
      list << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("inner"))

      # Text after the list inside the quote would otherwise continue
      # the last item.
      expect(tag.render(list, interface_for(*parents))).to eq("\n\n- inner\n\n\n")
    end

    context "with a list of the same kind in front of it" do
      def list_with_item(ordered:, text:)
        list = Markbridge::AST::List.new(ordered:)
        item = Markbridge::AST::ListItem.new
        item << Markbridge::AST::Text.new(text)
        list << item
      end

      # Renders a document with +children+ through the renderer, so the
      # renderer knows what it rendered in front of each list.
      def render_in_document(*children)
        document = Markbridge::AST::Document.new
        children.each { |child| document << child }
        renderer.render(document)
      end

      it "puts a comment between blank lines in front of the list" do
        first = list_with_item(ordered: false, text: "a")
        second = list_with_item(ordered: false, text: "b")

        expect(render_in_document(first, second)).to eq("\n\n- a\n\n\n\n\n<!---->\n\n\n\n- b\n\n\n")
      end

      it "separates two ordered lists" do
        first = list_with_item(ordered: true, text: "a")
        second = list_with_item(ordered: true, text: "b")

        expect(render_in_document(first, second)).to eq(
          "\n\n1. a\n\n\n\n\n<!---->\n\n\n\n1. b\n\n\n",
        )
      end

      it "separates two lists with nothing visible between them" do
        # A newline between two BBCode lists is a Text node of its own.
        between = {
          "whitespace" => Markbridge::AST::Text.new(" \n\t"),
          "a line break" => Markbridge::AST::LineBreak.new,
          "an empty list" => Markbridge::AST::List.new(ordered: false),
          "an element that renders to nothing" => Markbridge::AST::Bold.new,
        }

        between.each do |label, node|
          first = list_with_item(ordered: false, text: "a")
          second = list_with_item(ordered: false, text: "b")

          expect(render_in_document(first, node, second)).to include("<!---->"), label
        end
      end

      it "separates two nested lists with the comment on a line of its own, without blank lines" do
        # Blank lines inside the item would make the outer list loose.
        item = Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        item << list_with_item(ordered: false, text: "x") <<
          list_with_item(ordered: false, text: "y")
        outer = Markbridge::AST::List.new(ordered: false) << item

        expect(render_in_document(outer)).to eq("\n\n- a\n  - x\n  <!---->\n  - y\n\n\n")
      end

      it "separates two lists inside an element that has no tag" do
        # Such an element is not on the parent chain, the renderer still
        # knows it as the parent of the lists.
        wrapper = Class.new(Markbridge::AST::Element).new
        wrapper << list_with_item(ordered: false, text: "a")
        wrapper << list_with_item(ordered: false, text: "b")

        expect(render_in_document(wrapper)).to include("<!---->")
      end

      it "does not separate a list from an empty list in front of it" do
        # The empty list renders to nothing, a comment would stand alone.
        empty = Markbridge::AST::List.new(ordered: false)
        list = list_with_item(ordered: false, text: "b")

        expect(render_in_document(empty, list)).to eq("\n\n- b\n\n\n")
      end

      it "does not separate two lists with something visible between them" do
        # Emphasis renders to tokens, not to a String; what is visible in
        # them counts like text.
        between = {
          "text" => Markbridge::AST::Text.new("\nx\n"),
          "emphasis" => Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x"),
          "a quote" => Markbridge::AST::Quote.new << Markbridge::AST::Text.new("q"),
        }

        between.each do |label, node|
          first = list_with_item(ordered: false, text: "a")
          second = list_with_item(ordered: false, text: "b")

          expect(render_in_document(first, node, second)).not_to include("<!---->"), label
        end
      end

      it "looks only at the last list in front" do
        # The ordered list in the middle already separates the other two.
        first = list_with_item(ordered: false, text: "a")
        middle = list_with_item(ordered: true, text: "b")
        last = list_with_item(ordered: false, text: "c")

        expect(render_in_document(first, middle, last)).not_to include("<!---->")
      end

      it "separates two lists whose classes are subclasses of List" do
        list_class = Class.new(Markbridge::AST::List)
        first = list_class.new(ordered: false)
        first << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a"))
        second = list_class.new(ordered: false)
        second << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("b"))

        expect(render_in_document(first, second)).to include("<!---->")
      end

      it "does not separate an ordered list from an unordered one" do
        # A change of list kind starts a new list on its own.
        first = list_with_item(ordered: false, text: "a")
        second = list_with_item(ordered: true, text: "b")

        expect(render_in_document(first, second)).not_to include("<!---->")
      end

      it "does not separate a list from text in front of it" do
        list = list_with_item(ordered: false, text: "a")

        expect(render_in_document(Markbridge::AST::Text.new("before"), list)).to eq(
          "before\n\n- a\n\n\n",
        )
      end

      it "does not separate a list whose parent is not known" do
        list = list_with_item(ordered: false, text: "a")

        expect(tag.render(list, interface)).to eq("\n\n- a\n\n\n")
      end
    end

    context "in html_mode" do
      let(:context) { html_context }

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
