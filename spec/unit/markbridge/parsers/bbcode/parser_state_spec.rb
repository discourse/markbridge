# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::ParserState do
  let(:root) { Markbridge::AST::Document.new }
  let(:context) { described_class.new(root) }

  def token_for(source = "[b]", tag: "b")
    Markbridge::Parsers::BBCode::TagStartToken.new(tag:, attrs: {}, pos: 0, source:)
  end

  describe "#initialize" do
    it "starts with the given root as current" do
      expect(context.current).to eq(root)
    end

    it "starts with depth 0" do
      expect(context.depth).to eq(0)
    end

    it "starts with auto_closed_count at 0" do
      expect(context.auto_closed_count).to eq(0)
    end

    it "starts with depth_exceeded_count at 0" do
      expect(context.depth_exceeded_count).to eq(0)
    end

    it "starts with empty unclosed_raw_tags counting hash defaulting to 0" do
      expect(context.unclosed_raw_tags).to be_empty
      expect(context.unclosed_raw_tags["never-seen"]).to eq(0)
    end

    it "primes the node stack so #pop returns the original root" do
      # First pop should be a no-op returning root
      expect(context.pop).to eq(root)
      expect(context.current).to eq(root)
    end

    it "primes the node stack with the root so elements_from_current returns it" do
      expect(context.elements_from_current).to eq([root])
    end
  end

  describe "#push" do
    it "appends element to current and makes it current" do
      element = Markbridge::AST::Bold.new

      result = context.push(element)

      expect(root.children).to include(element)
      expect(context.current).to eq(element)
      expect(context.depth).to eq(1)
      expect(result).to be true
    end

    it "stacks pushes so #pop walks back through the lineage" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new

      context.push(bold)
      context.push(italic)

      expect(context.current).to eq(italic)
      expect(context.depth).to eq(2)

      context.pop
      expect(context.current).to eq(bold)
      context.pop
      expect(context.current).to eq(root)
    end

    it "raises MaxDepthExceededError naming the limit when no token is provided and depth would exceed MAX_DEPTH" do
      described_class::MAX_DEPTH.times { context.push(Markbridge::AST::Bold.new) }

      expect(context.depth).to eq(described_class::MAX_DEPTH)
      rejected = Markbridge::AST::Italic.new
      expect { context.push(rejected) }.to raise_error(
        Markbridge::Parsers::BBCode::MaxDepthExceededError,
        /#{described_class::MAX_DEPTH}/,
      )
      expect(context.current.children).not_to include(rejected)
      expect(context.depth).to eq(described_class::MAX_DEPTH)
    end

    context "with graceful degradation when a token is provided" do
      it "appends the token's source as Text on the current node and increments depth_exceeded_count" do
        described_class::MAX_DEPTH.times { context.push(Markbridge::AST::Bold.new) }
        leaf = context.current
        token = token_for("[i]", tag: "i")

        result = context.push(Markbridge::AST::Italic.new, token:)

        expect(result).to be false
        expect(context.depth_exceeded_count).to eq(1)
        expect(leaf.children.last).to be_a(Markbridge::AST::Text)
        expect(leaf.children.last.text).to eq("[i]")
        expect(context.depth).to eq(described_class::MAX_DEPTH)
      end

      it "does not push or change current when depth is exceeded" do
        described_class::MAX_DEPTH.times { context.push(Markbridge::AST::Bold.new) }
        before_current = context.current

        context.push(Markbridge::AST::Italic.new, token: token_for)

        expect(context.current).to eq(before_current)
      end

      it "increments depth_exceeded_count once per refused push" do
        described_class::MAX_DEPTH.times { context.push(Markbridge::AST::Bold.new) }

        3.times { context.push(Markbridge::AST::Italic.new, token: token_for) }

        expect(context.depth_exceeded_count).to eq(3)
      end
    end
  end

  describe "#pop" do
    it "returns to parent element and decrements depth" do
      element = Markbridge::AST::Bold.new
      context.push(element)

      result = context.pop

      expect(context.current).to eq(root)
      expect(context.depth).to eq(0)
      expect(result).to eq(root)
    end

    it "returns root when called on an already-empty stack" do
      expect(context.pop).to eq(root)
      expect(context.current).to eq(root)
      expect(context.depth).to eq(0)
    end

    it "walks back through nested pushes one level at a time" do
      b = Markbridge::AST::Bold.new
      i = Markbridge::AST::Italic.new
      context.push(b)
      context.push(i)

      expect(context.pop).to eq(b)
      expect(context.pop).to eq(root)
    end

    it "does not increment auto_closed_count" do
      context.push(Markbridge::AST::Bold.new)

      expect { context.pop }.not_to change(context, :auto_closed_count)
    end
  end

  describe "#add_child" do
    it "adds a child to current without changing current" do
      text = Markbridge::AST::Text.new("hello")

      context.add_child(text)

      expect(root.children).to include(text)
      expect(context.current).to eq(root)
    end
  end

  describe "#auto_close!" do
    it "increments auto_closed_count by 1 by default" do
      expect { context.auto_close! }.to change(context, :auto_closed_count).from(0).to(1)
    end

    it "increments auto_closed_count by the explicit count" do
      expect { context.auto_close!(3) }.to change(context, :auto_closed_count).from(0).to(3)
    end

    it "accumulates across calls" do
      context.auto_close!(2)
      context.auto_close!(4)

      expect(context.auto_closed_count).to eq(6)
    end
  end

  describe "#mark_unclosed_raw!" do
    it "increments the count for the named tag" do
      context.mark_unclosed_raw!("code")

      expect(context.unclosed_raw_tags["code"]).to eq(1)
    end

    it "accumulates the count for repeated marks of the same tag" do
      3.times { context.mark_unclosed_raw!("code") }

      expect(context.unclosed_raw_tags["code"]).to eq(3)
    end

    it "tracks distinct tags independently" do
      context.mark_unclosed_raw!("code")
      context.mark_unclosed_raw!("pre")

      expect(context.unclosed_raw_tags["code"]).to eq(1)
      expect(context.unclosed_raw_tags["pre"]).to eq(1)
    end
  end

  describe "#elements_from_current" do
    it "returns an empty array when the node stack has no entries" do
      empty_state = described_class.allocate
      empty_state.instance_variable_set(:@node_stack, [])

      expect(empty_state.elements_from_current).to eq([])
    end

    it "returns the full ancestry from current to root when no limit is given" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      context.push(bold)
      context.push(italic)

      expect(context.elements_from_current).to eq([italic, bold, root])
    end

    it "limits the returned ancestry to the requested depth (inclusive)" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      under = Markbridge::AST::Underline.new
      context.push(bold)
      context.push(italic)
      context.push(under)

      expect(context.elements_from_current(0)).to eq([under])
      expect(context.elements_from_current(1)).to eq([under, italic])
      expect(context.elements_from_current(2)).to eq([under, italic, bold])
    end

    it "caps the limit at the available stack depth" do
      bold = Markbridge::AST::Bold.new
      context.push(bold)

      expect(context.elements_from_current(99)).to eq([bold, root])
    end

    it "returns just current when only the root is on the stack" do
      expect(context.elements_from_current).to eq([root])
    end
  end
end
