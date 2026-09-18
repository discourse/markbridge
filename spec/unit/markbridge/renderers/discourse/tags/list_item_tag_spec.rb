# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ListItemTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }

  def interface_for(*parents, html_mode: false)
    context = Markbridge::Renderers::Discourse::RenderContext.new(parents, html_mode:)
    Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)
  end

  def item(*children)
    children.each_with_object(Markbridge::AST::ListItem.new) { |child, node| node << child }
  end

  def text(string)
    Markbridge::AST::Text.new(string)
  end

  def list(ordered: false, items: [])
    items.each_with_object(Markbridge::AST::List.new(ordered:)) { |child, node| node << child }
  end

  describe "#render" do
    it "renders an unordered list item with a dash" do
      interface = interface_for(list)

      expect(tag.render(item(text("item text")), interface)).to eq("- item text\n")
    end

    it "renders an ordered list item with a number" do
      interface = interface_for(list(ordered: true))

      expect(tag.render(item(text("item text")), interface)).to eq("1. item text\n")
    end

    it "indents a continuation line by the width of the marker" do
      interface = interface_for(list)

      expect(tag.render(item(text("line1\nline2")), interface)).to eq("- line1\n  line2\n")
    end

    it "keeps blank lines between paragraphs of an item" do
      interface = interface_for(list)
      node = item(text("First paragraph\n\nSecond paragraph"))

      expect(tag.render(node, interface)).to eq("- First paragraph\n\n  Second paragraph\n")
    end

    it "strips whitespace around the content" do
      interface = interface_for(list)

      expect(tag.render(item(text("  item text  ")), interface)).to eq("- item text\n")
    end

    it "renders the same output whatever the chain of ancestor lists is" do
      shallow = tag.render(item(text("nested item")), interface_for(list))
      deep = tag.render(item(text("nested item")), interface_for(list, list(ordered: true), list))

      expect(deep).to eq(shallow)
      expect(deep).to eq("- nested item\n")
    end

    it "does not indent a multi-line nested item beyond its own marker width" do
      interface = interface_for(list, list)

      expect(tag.render(item(text("line1\nline2")), interface)).to eq("- line1\n  line2\n")
    end

    it "renders without a parent list" do
      expect(tag.render(item(text("orphan item")), interface_for)).to eq("- orphan item\n")
    end

    # Kills mutations that drop the `if content.empty?` guard or the
    # early `return ""`. An empty ListItem has no children, so
    # render_children produces ""; without the guard the builder
    # would emit `"- \n"`.
    it "returns an empty string for a ListItem with no content" do
      expect(tag.render(item, interface_for(list))).to eq("")
    end

    # Kills the `interface.with_parent(element)` → `interface` /
    # `interface.with_parent(nil)` mutations. A nested list inside a
    # list item must see the outer ListItem in its parent chain so
    # ListTag#render treats it as a nested list (single \n wrapping
    # vs double \n\n).
    it "adds the current ListItem to the parent chain for children" do
      nested = list(items: [item(text("nested"))])

      result = tag.render(item(nested), interface_for(list))

      expect(result).to eq("- - nested\n")
    end

    context "with a nested list after other content" do
      it "attaches the nested list directly to the text in front of it" do
        nested = list(items: [item(text("a"))])
        node = item(text("parent\n\n"), nested)

        expect(tag.render(node, interface_for(list))).to eq("- parent\n  - a\n")
      end

      it "keeps the blank line when the line in front opens an HTML block" do
        nested = list(items: [item(text("a"))])
        node = item(Markbridge::AST::MarkdownText.new("<table>\n</table>\n"), nested)

        expect(tag.render(node, interface_for(list))).to eq("- <table>\n  </table>\n\n  - a\n")
      end

      it "keeps the blank line after an aligned block" do
        nested = list(items: [item(text("a"))])
        island = Markbridge::AST::MarkdownText.new(%(<div align="center">\n\nx\n\n</div>))
        node = item(island, nested)

        expect(tag.render(node, interface_for(list))).to eq(
          %(- <div align="center">\n\n  x\n\n  </div>\n\n  - a\n),
        )
      end

      it "does not keep the blank line when the line in front only looks like HTML" do
        nested = list(items: [item(text("a"))])
        node = item(Markbridge::AST::MarkdownText.new("<https://example.com>\n\n"), nested)

        expect(tag.render(node, interface_for(list))).to eq("- <https://example.com>\n  - a\n")
      end

      # Only the last line counts. Here the first line of the content
      # in front is plain text, so looking at the whole buffer would
      # miss the HTML block that the table opens.
      it "looks at the last line of the content, not at its first" do
        nested = list(items: [item(text("a"))])
        node = item(Markbridge::AST::MarkdownText.new("text\n\n<table>\n</table>\n"), nested)

        expect(tag.render(node, interface_for(list))).to eq(
          "- text\n\n  <table>\n  </table>\n\n  - a\n",
        )
      end

      # Content without a newline in it: the whole buffer is the last
      # line, so the offset the search starts from has to be zero.
      it "keeps the blank line when the whole content is one opening tag" do
        nested = list(items: [item(text("a"))])
        node = item(Markbridge::AST::MarkdownText.new("<div>"), nested)

        expect(tag.render(node, interface_for(list))).to eq("- <div>\n\n  - a\n")
      end

      it "tightens a nested list of a subclass of AST::List as well" do
        subclass = Class.new(Markbridge::AST::List)
        nested = subclass.new(ordered: false)
        nested << item(text("a"))
        node = item(text("parent\n\n"), nested)

        expect(tag.render(node, interface_for(list))).to eq("- parent\n  - a\n")
      end

      it "does not tighten in front of a child that is not a list" do
        node =
          item(Markbridge::AST::MarkdownText.new("a  \n"), Markbridge::AST::MarkdownText.new("b"))

        expect(tag.render(node, interface_for(list))).to eq("- a  \n  b\n")
      end
    end

    # Iterating the children by hand would lose the boundary rule that
    # Renderer#render_children applies between siblings.
    it "keeps the boundary comment between two emphasis siblings" do
      bold = Markbridge::AST::Bold.new << text("a")
      italic = Markbridge::AST::Italic.new << text("b")

      expect(tag.render(item(bold, italic), interface_for(list))).to eq("- **a**<!---->*b*\n")
    end

    context "in html_mode" do
      let(:interface) { interface_for(html_mode: true) }

      it "wraps content in <li>" do
        expect(tag.render(item(text("item text")), interface)).to eq("<li>item text</li>")
      end

      it "returns an empty string for an item with no content" do
        expect(tag.render(item, interface)).to eq("")
      end

      it "strips whitespace on both sides of the content" do
        expect(tag.render(item(text("  padded  ")), interface)).to eq("<li>padded</li>")
      end

      it "returns an empty string for content that is only whitespace" do
        expect(tag.render(item(text("   ")), interface)).to eq("")
      end

      it "does not tighten a nested list, which renders as HTML here" do
        nested = list(items: [item(text("a"))])

        expect(tag.render(item(text("parent"), nested), interface)).to eq(
          "<li>parent<ul><li>a</li></ul></li>",
        )
      end
    end
  end
end
