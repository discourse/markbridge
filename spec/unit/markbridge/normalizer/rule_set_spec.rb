# frozen_string_literal: true

RSpec.describe Markbridge::Normalizer::RuleSet do
  subject(:rule_set) { described_class.new }

  let(:walk_cache) { {} }

  describe "#resolve" do
    it "returns [nil, nil] when the child class is not in any rule" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      bold = Markbridge::AST::Bold.new
      expect(rule_set.resolve(bold, [Markbridge::AST::Url.new], walk_cache)).to eq([nil, nil])
    end

    it "returns [strategy, boundary] for the matching ancestor" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      url = Markbridge::AST::Url.new
      image = Markbridge::AST::Image.new

      strategy, boundary = rule_set.resolve(image, [url], walk_cache)
      expect(strategy).to eq(:hoist_after)
      expect(boundary).to be(url)
    end

    it "picks the OUTERMOST matching ancestor when several match" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Url, strategy: :unwrap)
      outer = Markbridge::AST::Url.new
      inner = Markbridge::AST::Url.new
      target = Markbridge::AST::Url.new

      _strategy, boundary = rule_set.resolve(target, [outer, inner], walk_cache)
      expect(boundary).to be(outer)
    end

    it "matches a subclass child against a rule for its base class" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      subclass_image = Class.new(Markbridge::AST::Image).new(src: "x")
      url = Markbridge::AST::Url.new

      strategy, boundary = rule_set.resolve(subclass_image, [url], walk_cache)
      expect(strategy).to eq(:hoist_after)
      expect(boundary).to be(url)
    end

    it "matches a subclass parent against a rule for its base class" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      subclass_url = Class.new(Markbridge::AST::Url).new

      strategy, boundary = rule_set.resolve(Markbridge::AST::Image.new, [subclass_url], walk_cache)
      expect(strategy).to eq(:hoist_after)
      expect(boundary).to be(subclass_url)
    end

    it "prefers a rule for the exact (parent, child) pair over an inherited one" do
      subclass_image = Class.new(Markbridge::AST::Image)
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.add(parent: Markbridge::AST::Url, child: subclass_image, strategy: :drop)

      strategy, =
        rule_set.resolve(subclass_image.new(src: "x"), [Markbridge::AST::Url.new], walk_cache)
      expect(strategy).to eq(:drop)
    end

    it "prefers child class specificity over parent class specificity" do
      subclass_url = Class.new(Markbridge::AST::Url)
      subclass_image = Class.new(Markbridge::AST::Image)
      # Exact parent, inherited child ...
      rule_set.add(parent: subclass_url, child: Markbridge::AST::Image, strategy: :drop)
      # ... loses against inherited parent, exact child.
      rule_set.add(parent: Markbridge::AST::Url, child: subclass_image, strategy: :textify)

      strategy, = rule_set.resolve(subclass_image.new(src: "x"), [subclass_url.new], walk_cache)
      expect(strategy).to eq(:textify)
    end

    it "prefers stack position over class specificity" do
      subclass_image = Class.new(Markbridge::AST::Image)
      # The outer ancestor matches only through the child's base class ...
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      # ... but still beats the exact-pair rule on the inner ancestor.
      rule_set.add(parent: Markbridge::AST::Bold, child: subclass_image, strategy: :drop)
      url = Markbridge::AST::Url.new
      bold = Markbridge::AST::Bold.new

      strategy, boundary = rule_set.resolve(subclass_image.new(src: "x"), [url, bold], walk_cache)
      expect(strategy).to eq(:hoist_after)
      expect(boundary).to be(url)
    end

    it "matches every node against a rule keyed on AST::Node" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Node, strategy: :drop)

      strategy, =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache)
      expect(strategy).to eq(:drop)
    end

    it "matches every ancestor against a parent rule keyed on AST::Node" do
      rule_set.add(parent: Markbridge::AST::Node, child: Markbridge::AST::Image, strategy: :drop)

      strategy, =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache)
      expect(strategy).to eq(:drop)
    end

    it "never matches a child rule keyed on a class outside the AST hierarchy" do
      rule_set.add(parent: Markbridge::AST::Url, child: Object, strategy: :drop)

      expect(
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache),
      ).to eq([nil, nil])
    end

    it "never matches a parent rule keyed on a class outside the AST hierarchy" do
      rule_set.add(parent: Object, child: Markbridge::AST::Image, strategy: :drop)

      expect(
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache),
      ).to eq([nil, nil])
    end

    it "matches a child whose class is AST::Node itself" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Node, strategy: :drop)

      strategy, =
        rule_set.resolve(Markbridge::AST::Node.new, [Markbridge::AST::Url.new], walk_cache)
      expect(strategy).to eq(:drop)
    end

    it "matches an ancestor whose class is AST::Node itself" do
      rule_set.add(parent: Markbridge::AST::Node, child: Markbridge::AST::Image, strategy: :drop)

      strategy, =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Node.new], walk_cache)
      expect(strategy).to eq(:drop)
    end

    it "returns [nil, nil] for a child object outside the AST" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)

      expect(rule_set.resolve(Object.new, [Markbridge::AST::Url.new], walk_cache)).to eq([nil, nil])
    end

    it "returns [nil, nil] for a child object of a class unrelated to AST::Node" do
      # Module#<= is nil (not false) for an unrelated class like String —
      # this pins the nil branch of the AST bound check.
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)

      expect(rule_set.resolve(+"plain", [Markbridge::AST::Url.new], walk_cache)).to eq([nil, nil])
    end

    it "skips an ancestor object outside the AST" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)
      url = Markbridge::AST::Url.new

      strategy, boundary =
        rule_set.resolve(Markbridge::AST::Image.new, [Object.new, url], walk_cache)
      expect(strategy).to eq(:drop)
      expect(boundary).to be(url)
    end

    it "skips an ancestor object of a class unrelated to AST::Node" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)
      url = Markbridge::AST::Url.new

      strategy, boundary = rule_set.resolve(Markbridge::AST::Image.new, [+"plain", url], walk_cache)
      expect(strategy).to eq(:drop)
      expect(boundary).to be(url)
    end

    it "skips an ancestor whose class has no rules at all" do
      rule_set.add(parent: Markbridge::AST::Bold, child: Markbridge::AST::Image, strategy: :drop)
      bold = Markbridge::AST::Bold.new

      # Url has no rules; Bold does — resolution must not stop at Url.
      strategy, boundary =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new, bold], walk_cache)
      expect(strategy).to eq(:drop)
      expect(boundary).to be(bold)
    end

    it "skips an ancestor that has rules but none for this child class" do
      rule_set.add(parent: Markbridge::AST::Url, child: Markbridge::AST::Url, strategy: :unwrap)
      rule_set.add(parent: Markbridge::AST::Bold, child: Markbridge::AST::Image, strategy: :drop)
      bold = Markbridge::AST::Bold.new

      # Url has a rules hash, but not one for Image — must fall through to Bold.
      strategy, boundary =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new, bold], walk_cache)
      expect(strategy).to eq(:drop)
      expect(boundary).to be(bold)
    end

    it "stores the per-class ancestry analysis in the caller's walk cache" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )

      rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache)

      # One entry per seen child class: the classes in its AST chain that
      # some rule targets as a child — here Image, but not Element or Node.
      expect(walk_cache[Markbridge::AST::Image]).to eq([Markbridge::AST::Image])
    end

    it "resolves through the prebuilt cache on a frozen rule set" do
      subclass_image = Class.new(Markbridge::AST::Image)
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze

      strategy, =
        rule_set.resolve(subclass_image.new(src: "x"), [Markbridge::AST::Url.new], walk_cache)
      expect(strategy).to eq(:hoist_after)
    end

    it "leaves the caller's walk cache untouched for classes known at freeze time" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze

      rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache)

      # The frozen cache answers directly; the walk cache is only for classes
      # defined after the freeze.
      expect(walk_cache).to be_empty
    end

    it "falls back to the walk cache for classes defined after the freeze" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze
      late_subclass = Class.new(Markbridge::AST::Image)

      strategy, =
        rule_set.resolve(late_subclass.new(src: "x"), [Markbridge::AST::Url.new], walk_cache)

      expect(strategy).to eq(:hoist_after)
      expect(walk_cache).to have_key(late_subclass)
    end

    it "trusts the walk cache, so one cache must not span rule set changes" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      # A seeded entry saying "no rule targets Image" wins over the walk —
      # this is why callers create a fresh walk cache per tree walk.
      walk_cache[Markbridge::AST::Image] = []

      expect(
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache),
      ).to eq([nil, nil])
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

      strategy, =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache)
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

    it "can be called twice without raising" do
      rule_set.freeze

      expect { rule_set.freeze }.not_to raise_error
    end

    it "prebuilds the candidates cache so resolve leaves the walk cache untouched" do
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze

      walk_cache = {}
      strategy, =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache)

      expect(strategy).to eq(:hoist_after)
      expect(walk_cache).to be_empty
    end

    it "covers subclasses known at freeze time in the prebuilt cache" do
      subclass_image = Class.new(Markbridge::AST::Image)
      rule_set.add(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      rule_set.freeze

      walk_cache = {}
      strategy, =
        rule_set.resolve(subclass_image.new(src: "x"), [Markbridge::AST::Url.new], walk_cache)

      expect(strategy).to eq(:hoist_after)
      expect(walk_cache).to be_empty
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

      strategy, =
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Url.new], walk_cache)
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
      expect(
        rule_set.resolve(Markbridge::AST::Image.new, [Markbridge::AST::Bold.new], walk_cache),
      ).to eq([nil, nil])
    end
  end
end
