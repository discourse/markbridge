# frozen_string_literal: true

RSpec.describe Markbridge::AST::Node do
  describe ".descendants" do
    it "contains the built-in node classes" do
      expect(described_class.descendants).to include(
        Markbridge::AST::Element,
        Markbridge::AST::Text,
        Markbridge::AST::Bold,
      )
    end

    it "records a new subclass when its class body runs" do
      subclass = Class.new(Markbridge::AST::Bold)

      expect(described_class.descendants).to include(subclass)
    end

    it "records indirect descendants too" do
      middle = Class.new(Markbridge::AST::Element)
      leaf = Class.new(middle)

      expect(described_class.descendants).to include(middle, leaf)
    end
  end

  describe ".ast_chain" do
    it "lists the class chain up to Node, most specific class first" do
      expect(Markbridge::AST::Bold.ast_chain).to eq(
        [Markbridge::AST::Bold, Markbridge::AST::Element, described_class],
      )
    end

    it "returns only Node itself for Node" do
      expect(described_class.ast_chain).to eq([described_class])
    end

    it "includes anonymous subclasses at the front" do
      subclass = Class.new(Markbridge::AST::Bold)

      expect(subclass.ast_chain).to eq(
        [subclass, Markbridge::AST::Bold, Markbridge::AST::Element, described_class],
      )
    end

    it "is frozen" do
      expect(Markbridge::AST::Bold.ast_chain).to be_frozen
    end

    it "returns the same array on every call (cached per class)" do
      expect(Markbridge::AST::Bold.ast_chain).to be(Markbridge::AST::Bold.ast_chain)
    end
  end
end
