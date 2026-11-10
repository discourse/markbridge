# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::RenderingInterface do
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { described_class.new(renderer, context) }

  describe "#context" do
    it "exposes the context it was constructed with" do
      expect(interface.context).to eq(context)
    end
  end

  # The four render methods hand the node and the context on to the
  # renderer, its own context when none is given.
  describe "the render methods" do
    let(:other_context) { Markbridge::Renderers::Discourse::RenderContext.new }
    let(:element) { Markbridge::AST::Bold.new }

    {
      render_node: :render,
      render_default: :render_default,
      render_tokens: :render_tokens,
    }.each do |method, renderer_method|
      it "##{method} delegates to the renderer with the current context, or the one given" do
        allow(renderer).to receive(renderer_method).and_return("rendered")

        expect(interface.public_send(method, element)).to eq("rendered")
        expect(renderer).to have_received(renderer_method).with(element, context:)

        interface.public_send(method, element, context: other_context)

        expect(renderer).to have_received(renderer_method).with(element, context: other_context)
      end
    end

    it "#render_children delegates to the renderer with the context and what follows" do
      allow(renderer).to receive(:render_children).and_return("rendered")

      expect(interface.render_children(element)).to eq("rendered")
      expect(renderer).to have_received(:render_children).with(element, context:, following: nil)

      interface.render_children(element, context: other_context, following: "[/x]")

      expect(renderer).to have_received(:render_children).with(
        element,
        context: other_context,
        following: "[/x]",
      )
    end

    it "#render_children passes the block on to the renderer" do
      element << Markbridge::AST::MarkdownText.new("a") << Markbridge::AST::MarkdownText.new("b")
      seen = []

      result = interface.render_children(element) { |buffer, child| seen << [buffer.dup, child] }

      expect(seen).to eq([["", element.children[0]], ["a", element.children[1]]])
      expect(result).to eq("ab")
    end
  end

  describe "context delegation" do
    let(:context) { instance_spy(Markbridge::Renderers::Discourse::RenderContext) }

    it "delegates with_parent to context" do
      element = Markbridge::AST::Bold.new

      interface.with_parent(element)

      expect(context).to have_received(:with_parent).with(element)
    end

    it "delegates find_parent to context" do
      interface.find_parent(Markbridge::AST::Bold)

      expect(context).to have_received(:find_parent).with(Markbridge::AST::Bold)
    end

    it "delegates count_parents to context" do
      interface.count_parents(Markbridge::AST::Bold)

      expect(context).to have_received(:count_parents).with(Markbridge::AST::Bold)
    end

    it "delegates has_parent? to context" do
      interface.has_parent?(Markbridge::AST::Bold)

      expect(context).to have_received(:has_parent?).with(Markbridge::AST::Bold)
    end

    it "delegates root? to context" do
      interface.root?

      expect(context).to have_received(:root?)
    end
  end

  describe "#previous_sibling and #next_sibling" do
    let(:first) { Markbridge::AST::Text.new("a") }
    let(:middle) { Markbridge::AST::Bold.new }
    let(:last) { Markbridge::AST::Text.new("b") }
    let(:parent) do
      paragraph = Markbridge::AST::Paragraph.new
      paragraph << first << middle << last
    end
    let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([parent]) }

    it "returns the neighbors among the children of the parent on the chain" do
      expect(interface.previous_sibling(middle)).to be(first)
      expect(interface.next_sibling(middle)).to be(last)
    end

    it "returns nil at the edges" do
      expect(interface.previous_sibling(first)).to be_nil
      expect(interface.next_sibling(last)).to be_nil
    end

    it "returns nil when the element is not a child of the parent" do
      stranger = Markbridge::AST::Text.new("x")

      expect(interface.previous_sibling(stranger)).to be_nil
      expect(interface.next_sibling(stranger)).to be_nil
    end

    it "finds the element by identity, not by equality" do
      # Two Text nodes with the same content compare equal. Only the
      # second one has the Bold in front of it.
      twin = Markbridge::AST::Text.new("a")
      parent << Markbridge::AST::Italic.new << twin

      expect(interface.previous_sibling(twin)).to be(parent.children[-2])
      expect(interface.previous_sibling(first)).to be_nil
    end

    it "returns nil when the context has no parent" do
      root_interface =
        described_class.new(renderer, Markbridge::Renderers::Discourse::RenderContext.new)

      expect(root_interface.previous_sibling(middle)).to be_nil
      expect(root_interface.next_sibling(middle)).to be_nil
    end

    it "returns the node any number of positions away" do
      expect(interface.sibling(last, offset: -2)).to be(first)
      expect(interface.sibling(first, offset: 2)).to be(last)
      expect(interface.sibling(middle, offset: 0)).to be(middle)
      expect(interface.sibling(first, offset: -1)).to be_nil
      expect(interface.sibling(last, offset: 1)).to be_nil
    end

    it "uses the position the renderer reports for the child it renders" do
      allow(renderer).to receive_messages(child_parent: parent, child_index: 2)

      expect(interface.previous_sibling(last)).to be(middle)
    end

    it "does not search the children when the renderer reports the position of the element" do
      allow(renderer).to receive_messages(child_parent: parent, child_index: 1)
      allow(parent.children).to receive(:index).and_raise("searched the children")

      expect(interface.previous_sibling(middle)).to be(first)
      expect(interface.next_sibling(middle)).to be(last)
    end

    it "searches the children when the renderer reports another position" do
      # The renderer reports the position of whatever it renders, the tag
      # may ask about another node.
      allow(renderer).to receive_messages(child_parent: parent, child_index: 2)

      expect(interface.previous_sibling(middle)).to be(first)
    end

    it "takes the parent from the renderer, also one that is not on the chain" do
      # An element without a tag never goes on the parent chain.
      wrapper = Markbridge::AST::Paragraph.new
      left = Markbridge::AST::Text.new("l")
      right = Markbridge::AST::Bold.new
      wrapper << left << right
      allow(renderer).to receive_messages(child_parent: wrapper, child_index: 1)

      expect(interface.previous_sibling(right)).to be(left)
      expect(interface.next_sibling(right)).to be_nil
    end

    it "searches the parent on the chain when the renderer renders another parent" do
      other = Markbridge::AST::Paragraph.new << Markbridge::AST::Text.new("x")
      allow(renderer).to receive_messages(child_parent: other, child_index: 0)

      expect(interface.previous_sibling(middle)).to be(first)
    end

    it "searches the children when the reported position is past the end" do
      allow(renderer).to receive_messages(child_parent: parent, child_index: 7)

      expect(interface.next_sibling(first)).to be(middle)
    end
  end

  describe "#previous_list" do
    it "asks the renderer" do
      list = Markbridge::AST::List.new
      element = Markbridge::AST::List.new
      allow(renderer).to receive(:previous_list).with(element).and_return(list)

      expect(interface.previous_list(element)).to be(list)
    end
  end

  describe "#choose_list_marker and #list_marker" do
    it "ask the renderer" do
      list = Markbridge::AST::List.new
      allow(renderer).to receive(:choose_list_marker).with(list, ordered: true).and_return("1) ")
      allow(renderer).to receive(:list_marker).with(list).and_return("* ")

      expect(interface.choose_list_marker(list, ordered: true)).to eq("1) ")
      expect(interface.list_marker(list)).to eq("* ")
    end
  end

  describe "#leading_list and #trailing_list" do
    let(:list) { Markbridge::AST::List.new }
    let(:element) { Markbridge::AST::Details.new }

    it "ask the renderer with the context" do
      allow(renderer).to receive(:leading_list).with(element, context, children: false).and_return(
        list,
      )
      allow(renderer).to receive(:trailing_list).with(element, context, children: false).and_return(
        list,
      )

      expect(interface.leading_list(element)).to be(list)
      expect(interface.trailing_list(element)).to be(list)
    end

    it "pass children: on" do
      allow(renderer).to receive(:leading_list).with(element, context, children: true).and_return(
        list,
      )
      allow(renderer).to receive(:trailing_list).with(element, context, children: true).and_return(
        list,
      )

      expect(interface.leading_list(element, children: true)).to be(list)
      expect(interface.trailing_list(element, children: true)).to be(list)
    end
  end

  describe "#previous_sibling and #next_sibling with a root element" do
    let(:first) { Markbridge::AST::Text.new("a") }
    let(:middle) { Markbridge::AST::Bold.new }
    let(:last) { Markbridge::AST::Text.new("b") }
    let(:parent) do
      paragraph = Markbridge::AST::Paragraph.new
      paragraph << first << middle << last
    end

    it "falls back to the root element when the chain is empty" do
      context = Markbridge::Renderers::Discourse::RenderContext.new.with_root(parent)
      root_interface = described_class.new(renderer, context)

      expect(root_interface.previous_sibling(middle)).to be(first)
      expect(root_interface.next_sibling(middle)).to be(last)
    end

    it "prefers the element on the chain over the root" do
      other = Markbridge::AST::Paragraph.new
      other << Markbridge::AST::Text.new("x")
      context = Markbridge::Renderers::Discourse::RenderContext.new([parent], root: other)
      chain_interface = described_class.new(renderer, context)

      expect(chain_interface.previous_sibling(middle)).to be(first)
    end
  end

  describe "#markdown_island" do
    let(:html_interface) do
      described_class.new(
        renderer,
        Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true),
      )
    end

    it "writes inline Markdown as it is outside an HTML block" do
      expect(interface.markdown_island("![a](upload://a.png)", block: false)).to eq(
        "![a](upload://a.png)",
      )
    end

    it "writes a block with a blank line on both sides outside an HTML block" do
      expect(interface.markdown_island("[poll]\n* a\n[/poll]", block: true)).to eq(
        "\n\n[poll]\n* a\n[/poll]\n\n",
      )
    end

    it "writes an island in a div inside an HTML block, block or not" do
      expect(html_interface.markdown_island("[poll]\n* a\n[/poll]", block: true)).to eq(
        "<div>\n\n[poll]\n* a\n[/poll]\n\n</div>",
      )
      expect(html_interface.markdown_island("![a](upload://a.png)", block: false)).to eq(
        "<div>\n\n![a](upload://a.png)\n\n</div>",
      )
    end

    it "passes the html_mode contract check inside an HTML block" do
      output = html_interface.markdown_island("[poll]\n* a\n[/poll]", block: true)

      expect(Markbridge::Renderers::Discourse::HtmlBlock.safe?(output)).to be(true)
    end
  end

  describe "#html_mode?" do
    it "delegates to context" do
      context = instance_double(Markbridge::Renderers::Discourse::RenderContext, html_mode?: true)
      interface =
        described_class.new(instance_double(Markbridge::Renderers::Discourse::Renderer), context)

      expect(interface.html_mode?).to be true
      expect(context).to have_received(:html_mode?)
    end
  end

  describe "#with_html_mode" do
    it "delegates to context with the supplied flag" do
      new_context = instance_double(Markbridge::Renderers::Discourse::RenderContext)
      context =
        instance_double(
          Markbridge::Renderers::Discourse::RenderContext,
          with_html_mode: new_context,
        )
      interface =
        described_class.new(instance_double(Markbridge::Renderers::Discourse::Renderer), context)

      expect(interface.with_html_mode(true)).to equal(new_context)
      expect(context).to have_received(:with_html_mode).with(true)
    end
  end

  describe "#block_context?" do
    it "returns true for AST::List" do
      expect(interface.block_context?(Markbridge::AST::List.new)).to be true
    end

    it "returns true for AST::HorizontalRule" do
      expect(interface.block_context?(Markbridge::AST::HorizontalRule.new)).to be true
    end

    it "returns false for non-Element values (e.g. AST::Text)" do
      expect(interface.block_context?(Markbridge::AST::Text.new("hi"))).to be false
    end

    it "returns true for a single-line AST::Code with block: true" do
      code = Markbridge::AST::Code.new(block: true)
      code << Markbridge::AST::Text.new("inline")

      expect(interface.block_context?(code)).to be true
    end

    it "returns false for a single-line AST::Code without the block flag" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("inline")

      expect(interface.block_context?(code)).to be false
    end

    it "returns true for a multi-line AST::Code without the block flag" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("line1\nline2")

      expect(interface.block_context?(code)).to be true
    end

    it "returns true for a single-line AST::Code subclass with block: true" do
      subclass = Class.new(Markbridge::AST::Code)
      code = subclass.new(block: true)
      code << Markbridge::AST::Text.new("inline")

      expect(interface.block_context?(code)).to be true
    end

    it "returns true when an Element child contains a newline in its text" do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("line1\nline2")

      expect(interface.block_context?(bold)).to be true
    end

    it "returns false when an Element has no newline-containing text children" do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("inline")

      expect(interface.block_context?(bold)).to be false
    end

    it "returns false for an empty Element" do
      expect(interface.block_context?(Markbridge::AST::Bold.new)).to be false
    end

    it "ignores non-Text children when scanning for newlines" do
      bold = Markbridge::AST::Bold.new
      inner = Markbridge::AST::Italic.new
      inner << Markbridge::AST::Text.new("inline")
      bold << inner

      expect(interface.block_context?(bold)).to be false
    end
  end
end
