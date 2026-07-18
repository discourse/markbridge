# frozen_string_literal: true

RSpec.describe Markbridge::Normalizer do
  # Concise tree builders. `el` wraps a klass with children; the helpers
  # name the common nodes.
  def el(klass, *children, **kwargs)
    node = kwargs.empty? ? klass.new : klass.new(**kwargs)
    children.each { |child| node << child }
    node
  end

  def doc(*children) = el(Markbridge::AST::Document, *children)
  def text(string) = Markbridge::AST::Text.new(string)
  def url(*children, href: "https://ex.com") = el(Markbridge::AST::Url, *children, href:)
  def image(src: "https://ex.com/i.png") = Markbridge::AST::Image.new(src:)

  # Any valid instance of the class; the rules only look at the class.
  def instance(klass)
    case klass.name.split("::").last
    when "Heading"
      klass.new(level: 1)
    when "Align"
      klass.new(alignment: "center")
    when "Url"
      klass.new(href: "u")
    when "Image"
      klass.new(src: "s")
    when "Poll"
      klass.new(name: "p")
    when "Event"
      klass.new(name: "e", starts_at: "2026-01-01")
    else
      klass.new
    end
  end

  # An instance of +container_klass+ holding +child+.
  def wrap(container_klass, child) = instance(container_klass).tap { |c| c << child }

  def short(klass) = klass.name.split("::").last

  # The default rules do not move an image out of a link (that is Discourse
  # policy a consumer adds). The examples below add that rule so they have a
  # simple case to work with.
  subject(:normalizer) do
    described_class.default.rule(
      parent: Markbridge::AST::Url,
      child: Markbridge::AST::Image,
      strategy: :hoist_after,
    )
  end

  describe ".default" do
    it "builds a fresh, customizable instance" do
      one = described_class.default
      two = described_class.default
      expect(one).to be_a(described_class)
      expect(one).not_to be(two)
      expect(one).not_to be_frozen
    end

    it "carries the default rules (a link inside a link is unwrapped)" do
      tree = doc(url(url(text("x"), href: "b"), href: "a"))
      described_class.default.normalize(tree)

      expect(tree.children.size).to eq(1)
      expect(tree.children.first.href).to eq("a")
    end
  end

  describe ".shared_default" do
    it "returns the same frozen instance on every call" do
      expect(described_class.shared_default).to be_a(described_class)
      expect(described_class.shared_default).to be(described_class.shared_default)
      expect(described_class.shared_default).to be_frozen
    end

    it "normalizes and can be reused, even though it is frozen" do
      shared = described_class.shared_default
      2.times do
        tree = doc(url(url(text("x"), href: "b"), href: "a"))
        expect(shared.normalize(tree)).to eq(
          [{ parent: "Url", child: "Url", strategy: :unwrap, count: 1 }],
        )
      end
    end
  end

  describe "default rules" do
    it "unwraps a link inside a link" do
      expect(described_class.default.violations(doc(url(url(text("x")))))).to contain_exactly(
        { parent: "Url", child: "Url", strategy: :unwrap },
      )
    end

    it "flags every block node inside every inline container" do
      described_class::INLINE_CONTAINERS.each do |container|
        described_class::BLOCK_NODES.each do |block|
          next if container == block

          found = described_class.default.violations(doc(wrap(container, instance(block))))
          expect(found).to include(
            { parent: short(container), child: short(block), strategy: :hoist_after },
          ),
          "(#{container}, #{block}) not flagged"
        end
      end
    end

    it "keeps an inline code span but flags a fenced one, in any inline container" do
      described_class::INLINE_CONTAINERS.each do |container|
        inline = el(Markbridge::AST::Code, text("x"))
        fenced = el(Markbridge::AST::Code, text("a\nb"))

        expect(described_class.default.violations(doc(wrap(container, inline)))).to eq([]),
        "inline code in #{container}"
        expect(described_class.default.violations(doc(wrap(container, fenced)))).to contain_exactly(
          { parent: short(container), child: "Code", strategy: :hoist_after },
        ),
        "fenced code in #{container}"
      end
    end

    it "does not flag a node that is both an inline container and a block against itself" do
      # Heading is in INLINE_CONTAINERS and in BLOCK_NODES. build_rules must not
      # add a (Heading, Heading) hoist rule, or a heading in a heading would move.
      heading = Markbridge::AST::Heading
      tree = doc(wrap(heading, instance(heading)))

      expect(described_class.default.violations(tree)).to eq([])
    end

    it "does not add Discourse policy: an image or mention in a link is not flagged" do
      expect(described_class.default.violations(doc(url(image)))).to eq([])
      mention = Markbridge::AST::Mention.new(name: "a")
      expect(described_class.default.violations(doc(url(mention)))).to eq([])
    end
  end

  describe "#rule" do
    it "is chainable" do
      expect(
        normalizer.rule(
          parent: Markbridge::AST::Url,
          child: Markbridge::AST::Mention,
          strategy: :textify,
        ),
      ).to be(normalizer)
    end

    it "replaces an existing rule for the same (parent, child) pair" do
      tree = doc(url(image))
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)
      normalizer.normalize(tree)

      # was :hoist_after, now :drop — image gone, nothing hoisted
      expect(tree.children).to eq([tree.children.first])
      expect(tree.children.first.children).to eq([])
    end

    it "raises on a frozen (shared) instance" do
      expect {
        described_class.shared_default.rule(
          parent: Markbridge::AST::Url,
          child: Markbridge::AST::Image,
          strategy: :drop,
        )
      }.to raise_error(FrozenError)
    end
  end

  describe "#normalize strategies" do
    it "hoists an image out of a link, leaves the (empty) link, and reports it" do
      tree = doc(url(image))
      report = normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Image])
      expect(tree.children.first.children).to eq([]) # empty Url survives (bare link)
      expect(report).to contain_exactly(
        { parent: "Url", child: "Image", strategy: :hoist_after, count: 1 },
      )
    end

    it "hoists to the OUTERMOST offending ancestor, across nested formatting" do
      # image inside bold inside link → hoist after the LINK, not the bold
      tree = doc(url(el(Markbridge::AST::Bold, image)))
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Image])
      # bold emptied by the hoist → removed (no empty ** **)
      expect(tree.children.first.children).to eq([])
    end

    it "prunes an emptied formatting wrapper but never an emptied Url" do
      tree = doc(url(el(Markbridge::AST::Bold, image)))
      normalizer.normalize(tree)

      expect(tree.descendants(Markbridge::AST::Bold)).to be_empty
      expect(tree.children.first).to be_a(Markbridge::AST::Url) # kept as bare link
    end

    it "unwraps an inner link, keeping its label text" do
      inner = url(text("click"), href: "https://b.com")
      tree = doc(url(inner, href: "https://a.com"))
      report = normalizer.normalize(tree)

      expect(tree.children.size).to eq(1)
      outer = tree.children.first
      expect(outer).to be_a(Markbridge::AST::Url)
      expect(outer.href).to eq("https://a.com")
      expect(outer.children.map { |c| [c.class, c.respond_to?(:text) ? c.text : nil] }).to eq(
        [[Markbridge::AST::Text, "click"]],
      )
      expect(report).to contain_exactly(
        { parent: "Url", child: "Url", strategy: :unwrap, count: 1 },
      )
    end

    it "textifies a node via a custom rule, projecting its plain text" do
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Mention,
        strategy: :textify,
      )
      tree = doc(url(text("hi "), Markbridge::AST::Mention.new(name: "alice")))
      normalizer.normalize(tree)

      link = tree.children.first
      expect(link.children.size).to eq(1) # "hi " + "@alice" coalesced
      expect(link.children.first.text).to eq("hi @alice")
    end

    it "drops a node via a custom rule" do
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)
      tree = doc(url(text("label"), image))
      normalizer.normalize(tree)

      link = tree.children.first
      expect(link.children.map(&:class)).to eq([Markbridge::AST::Text])
    end

    it "keeps a mention in a link silently (no report row)" do
      tree = doc(url(Markbridge::AST::Mention.new(name: "alice")))
      report = normalizer.normalize(tree)

      expect(tree.children.first.children.map(&:class)).to eq([Markbridge::AST::Mention])
      expect(report).to be_empty
    end
  end

  describe "#normalize ordering (moved subtrees walk against their new-place stack)" do
    it "keeps a legally-nested quote-in-quote intact when the outer quote is hoisted" do
      inner_quote = el(Markbridge::AST::Quote, text("deep"))
      outer_quote = el(Markbridge::AST::Quote, inner_quote)
      tree = doc(url(outer_quote))
      normalizer.normalize(tree)

      # outer quote hoisted after the (empty) link; inner quote STILL nested
      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Quote])
      hoisted = tree.children.last
      expect(hoisted.children).to contain_exactly(be_a(Markbridge::AST::Quote))
      expect(hoisted.children.first.children.first.text).to eq("deep")
    end

    it "leaves an image inside a quote inside a link where it is (in the quote)" do
      quote = el(Markbridge::AST::Quote, image)
      tree = doc(url(quote))
      normalizer.normalize(tree)

      # quote hoists out of the link; image stays IN the quote (not ripped out)
      hoisted_quote = tree.children.last
      expect(hoisted_quote).to be_a(Markbridge::AST::Quote)
      expect(hoisted_quote.children).to contain_exactly(be_a(Markbridge::AST::Image))
    end

    it "preserves document order for multiple hoists to one link" do
      img1 = Markbridge::AST::Image.new(src: "one")
      img2 = Markbridge::AST::Image.new(src: "two")
      tree = doc(url(img1, text("mid"), img2))
      normalizer.normalize(tree)

      # link keeps "mid"; images land after the link in original order
      link, first, second = tree.children
      expect(link).to be_a(Markbridge::AST::Url)
      expect(link.children.map(&:text)).to eq(["mid"])
      expect([first.src, second.src]).to eq(%w[one two])
    end
  end

  describe "#normalize fixpoint" do
    it "reaches a fixpoint: a second normalize reports nothing" do
      trees = [
        doc(url(el(Markbridge::AST::Bold, image))),
        doc(url(url(text("x"), href: "b"), href: "a")),
        doc(url(el(Markbridge::AST::Quote, el(Markbridge::AST::Quote, image)))),
        doc(url(url(url(text("deep"), href: "c"), href: "b"), href: "a")),
      ]

      trees.each do |tree|
        first = normalizer.normalize(tree)
        second = normalizer.normalize(tree)
        expect(first).not_to be_empty
        expect(second).to eq([]), "expected empty second report, got #{second.inspect}"
      end
    end
  end

  describe "#normalize inline-code predicate (Url, Code)" do
    it "keeps an inline code span in a link label" do
      code = el(Markbridge::AST::Code, text("x"))
      tree = doc(url(code))
      normalizer.normalize(tree)

      expect(tree.children.first).to be_a(Markbridge::AST::Url)
      expect(tree.children.first.children).to contain_exactly(be_a(Markbridge::AST::Code))
    end

    it "hoists a multi-line (fenced) code block out of a link label" do
      code = el(Markbridge::AST::Code, text("line1\nline2"))
      tree = doc(url(code))
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Code])
    end
  end

  describe "#normalize early exit" do
    it "returns an empty report and leaves a clean tree untouched" do
      tree = doc(el(Markbridge::AST::Bold, text("hi")))
      before = tree.children.first
      report = normalizer.normalize(tree)

      expect(report).to eq([])
      expect(tree.children.first).to be(before)
    end
  end

  describe "#violations" do
    it "reports would-be violations without mutating the tree" do
      tree = doc(url(image))
      found = normalizer.violations(tree)

      expect(found).to contain_exactly({ parent: "Url", child: "Image", strategy: :hoist_after })
      # unchanged
      expect(tree.children.first).to be_a(Markbridge::AST::Url)
      expect(tree.children.first.children).to contain_exactly(be_a(Markbridge::AST::Image))
    end

    it "omits explicitly-kept nodes (a mention in a link)" do
      tree = doc(url(Markbridge::AST::Mention.new(name: "alice")))
      expect(normalizer.violations(tree)).to eq([])
    end

    it "recurses into nested elements, finding violations at every depth" do
      # image nested two elements deep inside a link, plus the quote itself
      tree = doc(url(el(Markbridge::AST::Quote, el(Markbridge::AST::Bold, image))))
      found = normalizer.violations(tree)

      expect(found).to contain_exactly(
        { parent: "Url", child: "Quote", strategy: :hoist_after },
        { parent: "Url", child: "Image", strategy: :hoist_after },
      )
    end

    it "passes the boundary to a callable rule" do
      seen = []
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy:
          lambda do |boundary, _node|
            seen << boundary
            :drop
          end,
      )
      link = url(image)
      normalizer.violations(doc(link))

      expect(seen).to eq([link]) # the offending Url, not nil
    end

    it "resolves callable rules — inline code is kept (omitted), a code block reported" do
      inline = doc(url(el(Markbridge::AST::Code, text("x"))))
      block = doc(url(el(Markbridge::AST::Code, text("a\nb"))))

      expect(normalizer.violations(inline)).to eq([])
      expect(normalizer.violations(block)).to contain_exactly(
        { parent: "Url", child: "Code", strategy: :hoist_after },
      )
    end

    it "is empty once the tree has been normalized (validation property)" do
      tree = doc(url(el(Markbridge::AST::Bold, image)))
      normalizer.normalize(tree)
      expect(described_class.default.violations(tree)).to eq([])
    end
  end
end
