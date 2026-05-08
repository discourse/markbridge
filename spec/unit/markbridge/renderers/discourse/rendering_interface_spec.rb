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

  describe "#render_node" do
    it "delegates to the renderer with the supplied node and current context" do
      allow(renderer).to receive(:render).and_return("rendered")

      result = interface.render_node(:node)

      expect(renderer).to have_received(:render).with(:node, context:)
      expect(result).to eq("rendered")
    end

    it "uses an explicit context when one is passed" do
      other_context = Markbridge::Renderers::Discourse::RenderContext.new
      allow(renderer).to receive(:render).and_return("rendered")

      interface.render_node(:node, context: other_context)

      expect(renderer).to have_received(:render).with(:node, context: other_context)
    end
  end

  describe "#render_children" do
    it "delegates to renderer.render_children with the element and current context" do
      allow(renderer).to receive(:render_children).and_return("children")
      element = Markbridge::AST::Bold.new

      result = interface.render_children(element)

      expect(renderer).to have_received(:render_children).with(element, context:)
      expect(result).to eq("children")
    end

    it "uses an explicit context when one is passed" do
      other_context = Markbridge::Renderers::Discourse::RenderContext.new
      allow(renderer).to receive(:render_children).and_return("children")
      element = Markbridge::AST::Bold.new

      interface.render_children(element, context: other_context)

      expect(renderer).to have_received(:render_children).with(element, context: other_context)
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

  describe "#wrap_inline" do
    it "wraps content with the marker on both sides" do
      expect(interface.wrap_inline("text", "**")).to eq("**text**")
    end

    it "uses the close_marker when explicitly different from open_marker" do
      expect(interface.wrap_inline("text", "<u>", "</u>")).to eq("<u>text</u>")
    end

    it "returns content unchanged when content is whitespace-only" do
      expect(interface.wrap_inline("   ", "**")).to eq("   ")
    end

    it "returns content unchanged when content is Unicode whitespace (e.g. nbsp)" do
      # CommonMark treats U+00A0 as whitespace, so `** **` would not
      # parse as bold (the closing `**` is not right-flanking). Match
      # CommonMark's whitespace definition rather than Ruby's ASCII-only \S.
      expect(interface.wrap_inline(" ", "**")).to eq(" ")
    end

    it "returns content unchanged when content is empty" do
      expect(interface.wrap_inline("", "**")).to eq("")
    end

    it "preserves leading and trailing whitespace inside the wrap" do
      expect(interface.wrap_inline("  text  ", "**")).to eq("  **text**  ")
    end

    it "preserves leading and trailing Unicode whitespace (e.g. nbsp) outside the wrap" do
      # CommonMark requires the closing delimiter to be right-flanking
      # (not preceded by Unicode whitespace), so nbsp must be hoisted
      # outside the wrap just like ASCII space.
      nbsp = " "
      expect(interface.wrap_inline("#{nbsp}text#{nbsp}", "**")).to eq("#{nbsp}**text**#{nbsp}")
    end

    it "preserves leading and trailing whitespace independently when they differ" do
      # Leading 2 spaces, trailing tab — wrapper must keep each on its own side.
      expect(interface.wrap_inline("  text\t", "**")).to eq("  **text**\t")
    end

    it "wraps multi-line content (the inner regex must span newlines)" do
      expect(interface.wrap_inline("foo\nbar", "**")).to eq("**foo\nbar**")
    end

    context "when content already contains the open marker" do
      it "falls back to <strong> for **" do
        expect(interface.wrap_inline("a**b", "**")).to eq("<strong>a**b</strong>")
      end

      it "falls back to <em> for *" do
        expect(interface.wrap_inline("a*b", "*")).to eq("<em>a*b</em>")
      end

      it "falls back to <s> for ~~" do
        expect(interface.wrap_inline("a~~b", "~~")).to eq("<s>a~~b</s>")
      end

      it "still falls back when only the close_marker collides" do
        expect(interface.wrap_inline("a**b", "**", "**")).to eq("<strong>a**b</strong>")
      end

      it "falls back when only the close_marker (different from open_marker) is present in content" do
        expect(interface.wrap_inline("foo</closer>bar", "**", "</closer>")).to eq(
          "<strong>foo</closer>bar</strong>",
        )
      end

      it "falls back when only the open_marker (different from close_marker) is present in content" do
        expect(interface.wrap_inline("foo**bar", "**", "</closer>")).to eq(
          "<strong>foo**bar</strong>",
        )
      end

      it "wraps as-is when no fallback is configured for the marker" do
        # No HTML fallback for `~`; just wraps even though content contains the marker.
        # Actually: the conflict check still runs, falls through to the sub() since no case matches.
        expect(interface.wrap_inline("foo~bar", "~")).to eq("~foo~bar~")
      end
    end
  end

end
