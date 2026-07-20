# frozen_string_literal: true

RSpec.describe Markbridge::AST::Element do
  # Use concrete subclass for testing base class functionality
  subject(:test_element_class) { Class.new(Markbridge::AST::Element) }

  describe "#initialize" do
    it "defaults to empty children" do
      element = test_element_class.new
      expect(element.children).to eq([])
    end
  end

  describe "#<<" do
    subject(:element) { test_element_class.new }

    it "adds child to children array" do
      child = Markbridge::AST::Text.new("hello")
      element << child
      expect(element.children).to include(child)
    end

    it "merges consecutive text children" do
      element << Markbridge::AST::Text.new("hello")
      element << Markbridge::AST::Text.new(" world")

      expect(element.children.size).to eq(1)
      expect(element.children.first.text).to eq("hello world")
    end

    it "does not merge non-consecutive text children" do
      element << child1 = Markbridge::AST::Text.new("hello")
      element << child2 = test_element_class.new
      element << child3 = Markbridge::AST::Text.new("world")

      expect(element.children.size).to eq(3)
      expect(element.children).to eq([child1, child2, child3])
    end

    it "returns self for chaining" do
      result = element << Markbridge::AST::Text.new("test")
      expect(result).to eq(element)
    end

    it "raises TypeError when given an Array" do
      children = [Markbridge::AST::Text.new("hello"), Markbridge::AST::Text.new(" world")]

      expect { element << children }.to raise_error(
        TypeError,
        /\A<< on #{Regexp.escape(test_element_class.to_s)} expected a Markbridge::AST::Node, got Array\z/,
      )
    end

    it "raises TypeError for nil child" do
      expect { element << nil }.to raise_error(
        TypeError,
        /\A<< on #{Regexp.escape(test_element_class.to_s)} expected a Markbridge::AST::Node, got nil\z/,
      )
    end

    it "names the actual receiver class in the error (not just Element)" do
      doc = Markbridge::AST::Document.new

      expect { doc << nil }.to raise_error(
        TypeError,
        "<< on Markbridge::AST::Document expected a Markbridge::AST::Node, got nil",
      )
    end
  end

  describe "#each_descendant" do
    # Build a small tree:
    #
    #   Document
    #   ├── Paragraph
    #   │   ├── Text("hello ")
    #   │   └── Bold
    #   │       └── Text("world")
    #   └── HorizontalRule
    #
    let(:doc) { Markbridge::AST::Document.new }
    let(:paragraph) { Markbridge::AST::Paragraph.new }
    let(:bold) { Markbridge::AST::Bold.new }
    let(:text_hello) { Markbridge::AST::Text.new("hello ") }
    let(:text_world) { Markbridge::AST::Text.new("world") }
    let(:hr) { Markbridge::AST::HorizontalRule.new }

    before do
      bold << text_world
      paragraph << text_hello
      paragraph << bold
      doc << paragraph
      doc << hr
    end

    it "yields every descendant in depth-first pre-order" do
      seen = []
      doc.each_descendant { |node| seen << node }

      expect(seen).to eq([paragraph, text_hello, bold, text_world, hr])
    end

    it "returns self when given a block (chains)" do
      result = doc.each_descendant { |_| }
      expect(result).to be(doc)
    end

    it "returns an Enumerator when called without a block" do
      enum = doc.each_descendant
      expect(enum).to be_a(Enumerator)
      expect(enum.to_a).to eq([paragraph, text_hello, bold, text_world, hr])
    end

    it "is empty for a leaf Element with no children" do
      empty = test_element_class.new
      expect(empty.each_descendant.to_a).to eq([])
    end

    it "snapshots the children array of each Element so mid-walk replace_child is safe" do
      # Replacing a child you're about to descend into must not skip it —
      # the snapshot at entry to the parent's iteration uses the original
      # reference, so descent still visits the replaced subtree's
      # children if the replacement is an Element with children of
      # its own. Mirrors the trailing-window banner-eliding pattern.
      replacement_text = Markbridge::AST::Text.new("REPLACED")
      replacement = Markbridge::AST::Italic.new
      replacement << replacement_text

      seen = []
      doc.each_descendant do |node|
        seen << node
        doc.replace_child(paragraph, replacement) if node.equal?(paragraph)
      end

      # Walk continues into the *original* paragraph (snapshot), so the
      # original children are visited; the replacement is reflected in
      # @children afterward but isn't re-walked in this pass.
      expect(seen).to eq([paragraph, text_hello, bold, text_world, hr])
      expect(doc.children).to eq([replacement, hr])
    end

    it "does not visit children appended to a parent's array during iteration" do
      # The children array is dup'd at iteration entry, so appends made
      # during the walk are not re-visited. Without the dup, appending
      # to @children mid-walk would extend the iteration into the new
      # element — and if that element itself appends, you get unbounded
      # recursion.
      visited_count = 0
      doc.each_descendant do |_node|
        visited_count += 1
        doc.children << Markbridge::AST::Text.new("appended") if visited_count == 1
      end

      # Five original descendants only; the appended node is not seen.
      expect(visited_count).to eq(5)
      # …but it IS present in the parent's children after the walk.
      expect(doc.children.last).to be_a(Markbridge::AST::Text)
      expect(doc.children.last.text).to eq("appended")
    end
  end

  describe "#descendants" do
    let(:doc) { Markbridge::AST::Document.new }
    let(:paragraph) { Markbridge::AST::Paragraph.new }
    let(:bold) { Markbridge::AST::Bold.new }
    let(:text_one) { Markbridge::AST::Text.new("one") }
    let(:text_two) { Markbridge::AST::Text.new("two") }

    before do
      bold << text_two
      paragraph << text_one
      paragraph << bold
      doc << paragraph
    end

    it "returns every descendant as an Array when called with no class filter" do
      expect(doc.descendants).to eq([paragraph, text_one, bold, text_two])
    end

    it "filters by class, including subclass matches via is_a?" do
      # Bold is an Element subclass; Element itself isn't directly
      # constructed here, but the filter must match by is_a?, not by
      # exact class.
      expect(doc.descendants(Markbridge::AST::Text)).to eq([text_one, text_two])
      expect(doc.descendants(Markbridge::AST::Bold)).to eq([bold])
    end

    it "matches descendants by inheritance, not exact class (is_a?, not instance_of?)" do
      # Every Element subclass (Paragraph, Bold, Italic, …) is_a? Element.
      # instance_of?(Element) would match none of them, since Element
      # is the abstract base. Same logic for Text vs Node, etc.
      expect(doc.descendants(Markbridge::AST::Element)).to contain_exactly(paragraph, bold)
      expect(doc.descendants(Markbridge::AST::Node)).to contain_exactly(
        paragraph,
        text_one,
        bold,
        text_two,
      )
    end

    it "returns an empty array when no descendant matches the class filter" do
      expect(doc.descendants(Markbridge::AST::HorizontalRule)).to eq([])
    end

    it "returns an empty array for an Element with no children" do
      expect(test_element_class.new.descendants).to eq([])
    end
  end

  describe "#replace_child" do
    let(:element) { test_element_class.new }
    let(:first) { Markbridge::AST::Bold.new }
    let(:original) { Markbridge::AST::Italic.new }
    let(:last) { Markbridge::AST::Underline.new }
    let(:replacement) { Markbridge::AST::Strikethrough.new }

    before do
      element << first
      element << original
      element << last
    end

    it "swaps the child in place, preserving index" do
      element.replace_child(original, replacement)

      expect(element.children.size).to eq(3)
      expect(element.children[0]).to be(first)
      expect(element.children[1]).to be(replacement)
      expect(element.children[2]).to be(last)
    end

    it "returns self for chaining" do
      expect(element.replace_child(original, replacement)).to be(element)
    end

    it "raises ArgumentError when old_child is not a direct child" do
      stranger = Markbridge::AST::Bold.new

      expect { element.replace_child(stranger, replacement) }.to raise_error(
        ArgumentError,
        /child not found/,
      )
    end

    it "names the actual receiver class in the ArgumentError" do
      stranger = Markbridge::AST::Bold.new

      expect { element.replace_child(stranger, replacement) }.to raise_error(
        ArgumentError,
        /child not found in #{Regexp.escape(test_element_class.to_s)}/,
      )
    end

    it "raises TypeError when new_child is not a Node" do
      expect { element.replace_child(original, "a string") }.to raise_error(
        TypeError,
        /expected a Markbridge::AST::Node, got String/,
      )
    end

    it "raises TypeError when new_child is nil" do
      expect { element.replace_child(original, nil) }.to raise_error(
        TypeError,
        /expected a Markbridge::AST::Node, got nil/,
      )
    end

    it "names the actual receiver class in the TypeError" do
      expect { element.replace_child(original, 42) }.to raise_error(
        TypeError,
        /replace_child on #{Regexp.escape(test_element_class.to_s)} expected a Markbridge::AST::Node, got Integer/,
      )
    end
  end

  describe "#replace_children" do
    let(:element) { test_element_class.new }

    before { element << Markbridge::AST::Text.new("old") }

    it "swaps the entire child list" do
      replacement = [Markbridge::AST::Bold.new, Markbridge::AST::Italic.new]
      element.replace_children(replacement)

      expect(element.children).to eq(replacement)
    end

    it "returns self for chaining" do
      expect(element.replace_children([])).to be(element)
    end

    it "accepts an empty list" do
      element.replace_children([])
      expect(element.children).to eq([])
    end

    it "does NOT merge adjacent Text nodes (the merge invariant is #<< only)" do
      first = Markbridge::AST::Text.new("hello")
      second = Markbridge::AST::Text.new(" world")
      element.replace_children([first, second])

      expect(element.children).to eq([first, second])
    end

    it "raises TypeError when any entry is not a Node, naming the offending value" do
      expect { element.replace_children([Markbridge::AST::Bold.new, "nope"]) }.to raise_error(
        TypeError,
        /replace_children on #{Regexp.escape(test_element_class.to_s)} expected Markbridge::AST::Nodes, got String/,
      )
    end

    it "raises TypeError for a nil entry" do
      expect { element.replace_children([nil]) }.to raise_error(
        TypeError,
        /replace_children on #{Regexp.escape(test_element_class.to_s)} expected Markbridge::AST::Nodes, got nil/,
      )
    end
  end
end
