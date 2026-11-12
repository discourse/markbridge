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

  describe ".block_code? and .own_lines?" do
    it "takes code with the block flag or with a line break for a block" do
      span = el(Markbridge::AST::Code, text("x"))
      flagged = el(Markbridge::AST::Code, text("x"), block: true)
      lines = el(Markbridge::AST::Code, text("a"), text("b\nc"))
      # A child that is no text is not looked into.
      odd = el(Markbridge::AST::Code, Markbridge::AST::MarkdownText.new("a\nb"))

      expect([span, flagged, lines, odd].map { |code| described_class.block_code?(code) }).to eq(
        [false, true, true, false],
      )
      expect([span, flagged, lines].map { |code| described_class.own_lines?(code) }).to eq(
        [false, true, true],
      )
    end

    it "takes a spoiler with the block flag for a block" do
      inline = el(Markbridge::AST::Spoiler, text("x"))
      block = el(Markbridge::AST::Spoiler, text("x"), block: true)

      expect(described_class.own_lines?(inline)).to be(false)
      expect(described_class.own_lines?(block)).to be(true)
    end

    it "takes the block nodes and their subclasses for blocks, and nothing else" do
      subclass = Class.new(Markbridge::AST::Quote)

      expect(described_class.own_lines?(Markbridge::AST::Quote.new)).to be(true)
      expect(described_class.own_lines?(subclass.new)).to be(true)
      expect(described_class.own_lines?(Markbridge::AST::HorizontalRule.new)).to be(true)
      expect(described_class.own_lines?(Markbridge::AST::Bold.new)).to be(false)
      expect(described_class.own_lines?(text("x"))).to be(false)
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

    it "unwraps a link in a mail address, a mail address in a link and one in another" do
      email = ->(*children) do
        node = Markbridge::AST::Email.new(address: "a@example.com")
        children.each { |child| node << child }
        node
      end
      default = described_class.default

      expect(default.violations(doc(email.call(url(text("x")))))).to contain_exactly(
        { parent: "Email", child: "Url", strategy: :unwrap },
      )
      expect(default.violations(doc(url(email.call(text("x")))))).to contain_exactly(
        { parent: "Url", child: "Email", strategy: :unwrap },
      )
      expect(default.violations(doc(email.call(email.call(text("x")))))).to contain_exactly(
        { parent: "Email", child: "Email", strategy: :unwrap },
      )
    end

    it "counts a mail address, a color and a size as inline containers" do
      expect(described_class::INLINE_CONTAINERS).to include(
        Markbridge::AST::Email,
        Markbridge::AST::Color,
        Markbridge::AST::Size,
      )
    end

    # A heading stays one heading and the block goes behind it. Every
    # other container is split around the block.
    def moved_out_of(container)
      container == Markbridge::AST::Heading ? :hoist_after : :split
    end

    it "splits a paragraph around every block node, like an inline container" do
      paragraph = Markbridge::AST::Paragraph
      described_class::BLOCK_NODES.each do |block|
        found = described_class.default.violations(doc(wrap(paragraph, instance(block))))
        expect(found).to include({ parent: "Paragraph", child: short(block), strategy: :split }),
        "(Paragraph, #{block}) not flagged"
      end
      fenced = el(Markbridge::AST::Code, text("a\nb"))
      spoiler = el(Markbridge::AST::Spoiler, text("x"), block: true)
      expect(described_class.default.violations(doc(wrap(paragraph, fenced)))).to eq(
        [{ parent: "Paragraph", child: "Code", strategy: :split }],
      )
      expect(described_class.default.violations(doc(wrap(paragraph, spoiler)))).to eq(
        [{ parent: "Paragraph", child: "Spoiler", strategy: :split }],
      )
    end

    it "splits an inline spoiler around a block, and leaves a block in a block spoiler" do
      quote = -> { el(Markbridge::AST::Quote, text("q")) }
      inline = el(Markbridge::AST::Spoiler, quote.call)
      block = el(Markbridge::AST::Spoiler, quote.call, block: true)
      in_bold = el(Markbridge::AST::Spoiler, el(Markbridge::AST::Bold, quote.call), block: true)

      expect(described_class.default.violations(doc(inline))).to eq(
        [{ parent: "Spoiler", child: "Quote", strategy: :split }],
      )
      expect(described_class.default.violations(doc(block))).to eq([])
      expect(described_class.default.violations(doc(in_bold))).to eq(
        [{ parent: "Bold", child: "Quote", strategy: :split }],
      )
    end

    it "takes the formatting, the links and a spoiler along with a block, not a heading" do
      expect(described_class::CARRIED).to match_array(
        described_class::INLINE_CONTAINERS - [Markbridge::AST::Heading] +
          [Markbridge::AST::Spoiler],
      )
    end

    it "flags every block node inside every inline container" do
      described_class::INLINE_CONTAINERS.each do |container|
        described_class::BLOCK_NODES.each do |block|
          next if container == block

          found = described_class.default.violations(doc(wrap(container, instance(block))))
          expect(found).to include(
            { parent: short(container), child: short(block), strategy: moved_out_of(container) },
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
          { parent: short(container), child: "Code", strategy: moved_out_of(container) },
        ),
        "fenced code in #{container}"
      end
    end

    it "names a class without a name after its nearest named ancestor" do
      rule = Class.new(Markbridge::AST::HorizontalRule).new
      bold = el(Class.new(Markbridge::AST::Bold), rule)

      expect(described_class.default.violations(doc(bold))).to eq(
        [{ parent: "Bold", child: "HorizontalRule", strategy: :split }],
      )
    end

    it "keeps an inline spoiler but flags a block spoiler, in any inline container" do
      described_class::INLINE_CONTAINERS.each do |container|
        inline = el(Markbridge::AST::Spoiler, text("x"))
        block = el(Markbridge::AST::Spoiler, text("x"), block: true)

        expect(described_class.default.violations(doc(wrap(container, inline)))).to eq([]),
        "inline spoiler in #{container}"
        expect(described_class.default.violations(doc(wrap(container, block)))).to contain_exactly(
          { parent: short(container), child: "Spoiler", strategy: moved_out_of(container) },
        ),
        "block spoiler in #{container}"
      end
    end

    it "flags a single-line code span with the block flag set, in any inline container" do
      described_class::INLINE_CONTAINERS.each do |container|
        forced = el(Markbridge::AST::Code, text("x"), block: true)

        expect(described_class.default.violations(doc(wrap(container, forced)))).to contain_exactly(
          { parent: short(container), child: "Code", strategy: moved_out_of(container) },
        ),
        "forced block code in #{container}"
      end
    end

    it "unwraps a heading in a heading and does not move it out" do
      # Heading is in INLINE_CONTAINERS and in BLOCK_NODES. build_rules must not
      # add a (Heading, Heading) hoist rule, or a heading in a heading would move.
      heading = Markbridge::AST::Heading
      inner = heading.new(level: 2) << Markbridge::AST::Text.new("b")
      outer = heading.new(level: 1) << Markbridge::AST::Text.new("a") << inner
      tree = doc(outer)

      expect(described_class.default.violations(tree)).to eq(
        [{ parent: "Heading", child: "Heading", strategy: :unwrap }],
      )

      described_class.default.normalize(tree)

      expect(tree.children).to eq([outer])
      expect(outer.children.map(&:text)).to eq(["a b"])
    end

    it "does not add Discourse policy: an image or mention in a link is not flagged" do
      expect(described_class.default.violations(doc(url(image)))).to eq([])
      mention = Markbridge::AST::Mention.new(name: "a")
      expect(described_class.default.violations(doc(url(mention)))).to eq([])
    end
  end

  describe "#freeze" do
    # `#rule` adds to the rule set, it does not assign an ivar on the
    # normalizer. Freezing the normalizer alone would therefore still
    # let a rule through; the rule set has to be frozen as well.
    it "freezes the rule set, so no rule can be added afterwards" do
      normalizer.freeze

      expect {
        normalizer.rule(
          parent: Markbridge::AST::Url,
          child: Markbridge::AST::Image,
          strategy: :drop,
        )
      }.to raise_error(FrozenError)
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
    it "keeps a legally-nested quote-in-quote intact when the outer quote leaves a link" do
      inner_quote = el(Markbridge::AST::Quote, text("deep"))
      outer_quote = el(Markbridge::AST::Quote, inner_quote)
      tree = doc(url(outer_quote))
      normalizer.normalize(tree)

      # the link held nothing else and is gone; the inner quote is STILL
      # nested, and its text has the link now
      expect(tree.children).to eq([outer_quote])
      expect(outer_quote.children).to eq([inner_quote])
      link = inner_quote.children.first
      expect(link).to be_a(Markbridge::AST::Url)
      expect(link.children.first.text).to eq("deep")
    end

    it "leaves an image inside a quote inside a link where it is (in the quote)" do
      quote = el(Markbridge::AST::Quote, image)
      tree = doc(url(quote))
      normalizer.normalize(tree)

      # the quote leaves the link; the image stays IN the quote (not ripped
      # out). The copy of the link around it is left empty by the rule of
      # this normalizer, which moves an image out of a link, and is gone.
      expect(tree.children).to eq([quote])
      expect(quote.children).to contain_exactly(be_a(Markbridge::AST::Image))
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

      expect(tree.children).to eq([code])
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
        { parent: "Url", child: "Quote", strategy: :split },
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
        { parent: "Url", child: "Code", strategy: :split },
      )
    end

    it "is empty once the tree has been normalized (validation property)" do
      tree = doc(url(el(Markbridge::AST::Bold, image)))
      normalizer.normalize(tree)
      expect(described_class.default.violations(tree)).to eq([])
    end
  end
end
