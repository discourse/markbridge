# frozen_string_literal: true

RSpec.describe Markbridge::Normalizer::RuleSet do
  subject(:rule_set) { described_class.new }

  describe "#resolve" do
    it "returns [nil, nil] when the child class is not in any rule" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      bold = Markbridge::AST::Bold.new
      expect(rule_set.resolve(bold, [Markbridge::AST::Url.new])).to eq([nil, nil])
    end

    it "returns [strategy, boundary] for the matching ancestor" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      url = Markbridge::AST::Url.new
      image = Markbridge::AST::Image.new

      strategy, boundary = rule_set.resolve(image, [url])
      expect(strategy).to eq(:hoist_after)
      expect(boundary).to be(url)
    end

    it "picks the OUTERMOST matching ancestor when several match" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Url, strategy: :unwrap)
      outer = Markbridge::AST::Url.new
      inner = Markbridge::AST::Url.new
      target = Markbridge::AST::Url.new

      _strategy, boundary = rule_set.resolve(target, [outer, inner])
      expect(boundary).to be(outer)
    end

    it "matches by exact class, not is_a? — an anonymous subclass does not match" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      subclass_image = Class.new(Markbridge::AST::Image).new(src: "x")

      expect(rule_set.resolve(subclass_image, [Markbridge::AST::Url.new])).to eq([nil, nil])
    end

    it "does not match an anonymous subclass of the parent either" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      subclass_url = Class.new(Markbridge::AST::Url).new

      expect(rule_set.resolve(Markbridge::AST::Image.new, [subclass_url])).to eq([nil, nil])
    end

    it "skips an ancestor whose class has no rules at all" do
      rule_set.add(parent: Markbridge::AST::Bold, child: Markbridge::AST::Image, strategy: :drop)
      bold = Markbridge::AST::Bold.new

      # Url has no rules; Bold does — resolution must not stop at Url.
      strategy, boundary =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new, bold])
      expect(strategy).to eq(:drop)
      expect(boundary).to be(bold)
    end

    it "skips an ancestor that has rules but none for this child class" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Url, strategy: :unwrap)
      rule_set.add(parent: Markbridge::AST::Bold, child: Markbridge::AST::Image, strategy: :drop)
      bold = Markbridge::AST::Bold.new

      # Url has a rules hash, but not one for Image — must fall through to Bold.
      strategy, boundary =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new, bold])
      expect(strategy).to eq(:drop)
      expect(boundary).to be(bold)
    end
  end

  describe "#add override" do
    it "replaces an earlier rule for the same (parent, child) pair" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)

      strategy, = rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new])
      expect(strategy).to eq(:drop)
    end

    it "returns self for chaining" do
      expect(
        rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop),
      ).to be(rule_set)
    end

    it "accepts a callable strategy" do
      callable = ->(_boundary, _node) { :keep }
      expect {
        rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Code, strategy: callable)
      }.not_to raise_error
    end

    it "raises for an unknown symbol strategy" do
      expect {
        rule_set.add(
          parent: Markbridge::AST::Url,
          child: Markbridge::AST::Image,
          strategy: :explode,
        )
      }.to raise_error(ArgumentError, /unknown strategy :explode/)
    end
  end

  describe "#freeze" do
    it "freezes the receiver (via super)" do
      rule_set.freeze
      expect(rule_set).to be_frozen
    end

    it "makes adding to an EXISTING parent raise (inner hash deep-frozen)" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze

      expect {
        rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Url, strategy: :unwrap)
      }.to raise_error(FrozenError)
    end

    it "makes adding a NEW parent raise (top-level hash frozen)" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze

      expect {
        rule_set.add(parent: Markbridge::AST::Bold, child: Markbridge::AST::Image, strategy: :drop)
      }.to raise_error(FrozenError)
    end

    # The raise alone doesn't prove *which* collection stopped the write —
    # a later-frozen collection would still raise while an earlier unfrozen
    # one silently accepted the rule. These re-add an ALREADY-registered
    # child class (Image) so the child-class fast-reject can't mask a sneak,
    # then check the strategy did not change.
    it "deep-freezes inner hashes so a raised add cannot mutate shared state" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze

      begin
        rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)
      rescue FrozenError
        # expected
      end

      strategy, = rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new])
      expect(strategy).to eq(:hoist_after) # unchanged; :drop never sneaked in
    end

    it "freezes the top-level hash so a raised new-parent add cannot mutate shared state" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze

      begin
        rule_set.add(parent: Markbridge::AST::Bold, child: Markbridge::AST::Image, strategy: :drop)
      rescue FrozenError
        # expected
      end

      # No (Bold, *) parent bucket was created before the raise.
      expect(rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Bold.new])).to eq(
        [nil, nil],
      )
    end
  end
end
