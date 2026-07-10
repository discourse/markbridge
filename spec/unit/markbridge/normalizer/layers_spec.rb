# frozen_string_literal: true

RSpec.describe Markbridge::Normalizer::Layers do
  # resolve() only looks at classes, so any valid instance of the class
  # works; this supplies the few constructors that need arguments.
  def instance(klass)
    case klass.name.split("::").last
    when "Heading"
      klass.new(level: 1)
    when "Align"
      klass.new(alignment: "center")
    when "Color"
      klass.new(color: "red")
    when "Size"
      klass.new(size: "5")
    when "Email"
      klass.new(address: "a@b.c")
    when "Url"
      klass.new(href: "u")
    when "Image"
      klass.new(src: "s")
    when "Mention"
      klass.new(name: "alice")
    when "Upload"
      klass.new(sha1: "x")
    when "Poll"
      klass.new(name: "p")
    when "Event"
      klass.new(name: "e", starts_at: "2026-01-01")
    else
      klass.new
    end
  end

  def resolve(rules, parent, child)
    strategy, = rules.resolve(instance(child), [instance(parent)])
    strategy
  end

  describe ".common_mark" do
    subject(:rules) { described_class.common_mark }

    it "unwraps a link inside a link" do
      expect(resolve(rules, Markbridge::AST::Url, Markbridge::AST::Url)).to eq(:unwrap)
    end

    it "hoists every block node out of every inline container" do
      described_class::INLINE_CONTAINERS.each do |container|
        described_class::BLOCK_NODES.each do |block|
          next if container == block

          expect(resolve(rules, container, block)).to eq(:hoist_after),
          "expected (#{container}, #{block}) => :hoist_after"
        end
      end
    end

    it "adds no rule for a container that is also a block node against itself" do
      # Heading is in both lists; the `next if container == block` guard must
      # skip it, leaving (Heading, Heading) unmatched.
      expect(resolve(rules, Markbridge::AST::Heading, Markbridge::AST::Heading)).to be_nil
    end

    it "keeps an inline (single-line) code span in a link" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("x")
      strategy, = rules.resolve(code, [instance(Markbridge::AST::Url)])
      expect(strategy.call(nil, code)).to eq(:keep)
    end

    it "hoists a multi-line code block out of a link" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("a\nb")
      strategy, = rules.resolve(code, [instance(Markbridge::AST::Url)])
      expect(strategy.call(nil, code)).to eq(:hoist_after)
    end

    it "does NOT carry the Discourse policy (no image-in-link rule)" do
      expect(resolve(rules, Markbridge::AST::Url, Markbridge::AST::Image)).to be_nil
      expect(resolve(rules, Markbridge::AST::Url, Markbridge::AST::Mention)).to be_nil
    end
  end

  describe ".discourse" do
    subject(:rules) { described_class.discourse }

    it "inherits the CommonMark link-in-link rule" do
      expect(resolve(rules, Markbridge::AST::Url, Markbridge::AST::Url)).to eq(:unwrap)
    end

    it "hoists every image-like and Discourse block out of a link" do
      described_class::DISCOURSE_HOIST_FROM_URL.each do |child|
        expect(resolve(rules, Markbridge::AST::Url, child)).to eq(:hoist_after),
        "expected (Url, #{child}) => :hoist_after"
      end
    end

    it "keeps a mention in a link" do
      expect(resolve(rules, Markbridge::AST::Url, Markbridge::AST::Mention)).to eq(:keep)
    end
  end
end
