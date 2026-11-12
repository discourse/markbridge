# frozen_string_literal: true

# The Walker is exercised through the public Normalizer#normalize (no private
# calls), but lives under a describe matching the subject so mutant selects
# these as the engine's tests.
RSpec.describe Markbridge::Normalizer::Walker do
  def el(klass, *children, **kwargs)
    node = kwargs.empty? ? klass.new : klass.new(**kwargs)
    children.each { |child| node << child }
    node
  end

  def doc(*children) = el(Markbridge::AST::Document, *children)

  # The default rules split bold, a link and the other inline containers
  # around a block. Only a heading still lets the block go behind it.
  # The examples for that strategy use bold and links, so they run with
  # +:hoist_after+ for every inline container, and with a paragraph and
  # a spoiler that have no say.
  def hoisting
    ast = Markbridge::AST
    normalizer = Markbridge::Normalizer.default
    pass = ->(_boundary, _node) { :pass }
    blocks = [*Markbridge::Normalizer::BLOCK_NODES, ast::Code, ast::Spoiler]
    blocks.each do |block|
      normalizer.rule(parent: ast::Paragraph, child: block, strategy: pass)
      normalizer.rule(parent: ast::Spoiler, child: block, strategy: pass)
    end
    Markbridge::Normalizer::INLINE_CONTAINERS.each do |container|
      Markbridge::Normalizer::BLOCK_NODES.each do |block|
        strategy = container == block ? :unwrap : :hoist_after
        normalizer.rule(parent: container, child: block, strategy:)
      end
      normalizer.rule(
        parent: container,
        child: ast::Code,
        strategy: ->(_b, node) { Markbridge::Normalizer.block_code?(node) ? :hoist_after : :keep },
      )
      normalizer.rule(
        parent: container,
        child: ast::Spoiler,
        strategy: ->(_b, node) { node.block ? :hoist_after : :keep },
      )
    end
    normalizer
  end
  def text(string) = Markbridge::AST::Text.new(string)
  def url(*children, href: "https://ex.com") = el(Markbridge::AST::Url, *children, href:)
  def image(src: "https://ex.com/i.png") = Markbridge::AST::Image.new(src:)

  # The default rules do not move an image out of a link. These engine
  # examples add that rule so they have a simple violation to use.
  let(:normalizer) do
    hoisting.rule(
      parent: Markbridge::AST::Url,
      child: Markbridge::AST::Image,
      strategy: :hoist_after,
    )
  end

  describe "split" do
    ast = Markbridge::AST

    def bold(*children) = el(Markbridge::AST::Bold, *children)
    def italic(*children) = el(Markbridge::AST::Italic, *children)
    def quote(*children) = el(Markbridge::AST::Quote, *children)

    # The tree as nested arrays of class names and texts.
    def shape(node)
      return node.text if node.respond_to?(:text)

      children = node.is_a?(Markbridge::AST::Element) ? node.children : []
      [node.class.name.split("::").last, *children.map { |child| shape(child) }]
    end

    def normalized(*children, with: Markbridge::Normalizer.default)
      tree = doc(*children)
      with.normalize(tree)
      shape(tree).drop(1)
    end

    it "cuts the element at the block and gives the text in the block a copy of it" do
      original = bold(text("a"), quote(text("q")), text("c"))
      tree = doc(original)
      Markbridge::Normalizer.default.normalize(tree)

      expect(shape(tree)).to eq(["Document", %w[Bold a], ["Quote", %w[Bold q]], %w[Bold c]])
      expect(tree.children.first).to equal(original)
      expect(tree.children.last).not_to equal(original)
    end

    it "cuts every element between the block and the outermost one" do
      inner = bold(text("a"), quote(text("q")), text("c"))

      expect(normalized(italic(text("x"), inner, text("y")))).to eq(
        [
          ["Italic", "x", %w[Bold a]],
          ["Quote", ["Italic", %w[Bold q]]],
          ["Italic", %w[Bold c], "y"],
        ],
      )
    end

    it "leaves no element in front of a block that was the first thing in it" do
      original = bold(quote(text("q")), text("c"))
      tree = doc(original)
      Markbridge::Normalizer.default.normalize(tree)

      expect(shape(tree)).to eq(["Document", ["Quote", %w[Bold q]], %w[Bold c]])
      expect(tree.children.last).not_to equal(original)
    end

    it "leaves no element behind a block that was the last thing in it" do
      expect(normalized(bold(text("a"), quote(text("q"))))).to eq(
        [%w[Bold a], ["Quote", %w[Bold q]]],
      )
    end

    it "leaves nothing of a link that held only the block, which is no empty link then" do
      expect(normalized(url(quote(text("q"))))).to eq([["Quote", %w[Url q]]])
    end

    it "leaves out a part that is whitespace, and keeps one with a word" do
      expect(normalized(bold(text(" "), quote(text("q")), text(" \n")))).to eq(
        [["Quote", %w[Bold q]]],
      )
      expect(normalized(bold(text(" a"), quote(text("q")), italic(text(" "))))).to eq(
        [["Bold", " a"], ["Quote", %w[Bold q]], ["Bold", ["Italic", " "]]],
      )
    end

    it "takes the whitespace off the text at a cut, on both sides" do
      tree = bold(text(" a "), quote(text("1")), text(" b \n"), quote(text("2")), text(" c "))

      expect(normalized(tree)).to eq(
        [["Bold", " a"], ["Quote", %w[Bold 1]], %w[Bold b], ["Quote", %w[Bold 2]], ["Bold", "c "]],
      )
    end

    it "removes a text at a cut that was only whitespace, and leaves an element there alone" do
      spaced = italic(text(" i "))
      tree = bold(spaced, text(" "), quote(text("1")), text(" "), italic(text(" j ")))

      expect(normalized(tree)).to eq(
        [["Bold", ["Italic", " i "]], ["Quote", %w[Bold 1]], ["Bold", ["Italic", " j "]]],
      )
    end

    it "cuts at every block" do
      first = quote(text("1"))
      second = quote(text("2"))

      expect(normalized(bold(text("a"), first, text("b"), second, text("c")))).to eq(
        [%w[Bold a], ["Quote", %w[Bold 1]], %w[Bold b], ["Quote", %w[Bold 2]], %w[Bold c]],
      )
      expect(normalized(bold(text("a"), quote(text("1")), quote(text("2")), text("c")))).to eq(
        [%w[Bold a], ["Quote", %w[Bold 1]], ["Quote", %w[Bold 2]], %w[Bold c]],
      )
    end

    it "splits a paragraph too, which has nothing to take along" do
      paragraph =
        el(ast::Paragraph, text("a"), bold(text("b"), quote(text("q")), text("c")), text("d"))

      expect(normalized(paragraph)).to eq(
        [["Paragraph", "a", %w[Bold b]], ["Quote", %w[Bold q]], ["Paragraph", %w[Bold c], "d"]],
      )
    end

    it "takes only the elements along that the block was in" do
      tree = bold(italic(text("i")), quote(text("q")), el(ast::Underline, text("u")))

      expect(normalized(tree)).to eq(
        [["Bold", %w[Italic i]], ["Quote", %w[Bold q]], ["Bold", %w[Underline u]]],
      )
    end

    it "takes an inline spoiler along, and splits it" do
      spoiler = el(ast::Spoiler, text("a"), quote(text("q")), text("c"))

      expect(normalized(spoiler)).to eq([%w[Spoiler a], ["Quote", %w[Spoiler q]], %w[Spoiler c]])
    end

    it "leaves a block spoiler whole and splits what is in it" do
      spoiler = el(ast::Spoiler, bold(text("a"), quote(text("q"))), quote(text("r")), block: true)

      expect(normalized(spoiler)).to eq(
        [["Spoiler", %w[Bold a], ["Quote", %w[Bold q]], %w[Quote r]]],
      )
    end

    it "splits an element that is no formatting too, and does not take it along" do
      holder = stub_const("Holder", Class.new(ast::Element))
      tree = italic(el(holder, bold(text("a"), quote(text("q")))))

      expect(normalized(tree)).to eq(
        [["Italic", ["Holder", %w[Bold a]]], ["Quote", ["Italic", %w[Bold q]]]],
      )
    end

    it "lets a block go behind a heading, with no copy of what it was in" do
      heading = el(ast::Heading, bold(text("a"), quote(text("q")), text("b")), level: 2)

      expect(normalized(heading)).to eq([["Heading", ["Bold", "a b"]], %w[Quote q]])
    end

    it "reports each block that was split out, by the outermost element" do
      tree = doc(italic(bold(quote(text("1")), quote(text("2")))), url(el(ast::List)))

      expect(Markbridge::Normalizer.default.normalize(tree)).to contain_exactly(
        { parent: "Italic", child: "Quote", strategy: :split, count: 2 },
        { parent: "Url", child: "List", strategy: :split, count: 1 },
      )
      expect(Markbridge::Normalizer.default.normalize(tree)).to eq([])
    end

    it "walks the block against the place it gets: a link in it is no link in a link" do
      inner = url(text("q"), href: "https://ex.com/inner")

      expect(normalized(bold(url(quote(inner))))).to eq([["Quote", ["Bold", %w[Url q]]]])
    end

    it "splits again for a block in a block that was split out" do
      nested = quote(italic(text("a"), el(ast::List, el(ast::ListItem, text("l"))), text("c")))

      expect(normalized(bold(nested))).to eq(
        [
          [
            "Quote",
            ["Bold", %w[Italic a]],
            ["List", ["ListItem", ["Bold", %w[Italic l]]]],
            ["Bold", %w[Italic c]],
          ],
        ],
      )
    end

    it "removes a copy that a rule leaves empty, also a link" do
      custom = Markbridge::Normalizer.default
      custom.rule(parent: ast::Url, child: ast::Image, strategy: :hoist_after)

      expect(normalized(url(quote(image)), with: custom)).to eq([["Quote", ["Image"]]])
    end

    it "splits the outer link when the block is in a link that is unwrapped" do
      inner = url(bold(text("a"), quote(text("q")), text("b")), href: "https://ex.com/inner")

      expect(normalized(url(text("x"), inner, text("y")))).to eq(
        [["Url", "x", %w[Bold a]], ["Quote", ["Url", %w[Bold q]]], ["Url", %w[Bold b], "y"]],
      )
    end

    it "puts the parts of a block that is hoisted and split behind its boundary" do
      paragraph = el(ast::Paragraph, text("a"), quote(text("q")), text("b"))
      heading = el(ast::Heading, text("h"), paragraph, level: 2)

      expect(normalized(heading)).to eq(
        [%w[Heading h], %w[Paragraph a], %w[Quote q], %w[Paragraph b]],
      )
    end

    it "leaves the parts where they were when a rule splits the document" do
      custom = Markbridge::Normalizer.default
      custom.rule(parent: ast::Document, child: ast::HorizontalRule, strategy: :split)

      expect(normalized(text("a"), ast::HorizontalRule.new, bold(text("b")), with: custom)).to eq(
        ["a", ["HorizontalRule"], %w[Bold b]],
      )
    end

    it "keeps the space a hoisted block left at the start of the first part and at the end of the last" do
      custom = Markbridge::Normalizer.default
      custom.rule(parent: ast::Bold, child: ast::HorizontalRule, strategy: :hoist_after)
      rule = -> { ast::HorizontalRule.new }
      tree = bold(rule.call, text("a"), quote(text("q")), text("b"), rule.call)

      expect(normalized(text("x"), tree, text("y"), with: custom)).to eq(
        [
          "x ",
          %w[Bold a],
          ["HorizontalRule"],
          ["HorizontalRule"],
          ["Quote", %w[Bold q]],
          %w[Bold b],
          " y",
        ],
      )
    end

    it "keeps no space where the parts start and end with text" do
      custom = Markbridge::Normalizer.default
      custom.rule(parent: ast::Bold, child: ast::HorizontalRule, strategy: :hoist_after)
      tree = bold(text("a"), ast::HorizontalRule.new, quote(text("q")), text("b"))

      expect(normalized(text("x"), tree, text("y"), with: custom)).to eq(
        ["x", %w[Bold a], ["HorizontalRule"], ["Quote", %w[Bold q]], %w[Bold b], "y"],
      )
    end
  end

  describe "hoist_after" do
    it "moves an image out of a link, reports it, and leaves the empty link" do
      img = image
      tree = doc(url(img))
      report = normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Image])
      expect(tree.children.last).to be(img) # the same node, moved
      expect(tree.children.first.children).to eq([])
      expect(report).to eq([{ parent: "Url", child: "Image", strategy: :hoist_after, count: 1 }])
    end

    it "does not push a bubble entry when the hoisted node is pruned to nil" do
      # An empty prunable wrapper hoisted out normalizes to nil — it must not
      # be pushed as a [nil, boundary] bubble (which would splice a nil child).
      custom = hoisting
      custom.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Bold,
        strategy: :hoist_after,
      )
      tree = doc(url(Markbridge::AST::Bold.new)) # empty bold

      expect { custom.normalize(tree) }.not_to raise_error
      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url])
      expect(tree.children.first.children).to eq([])
    end

    it "lands a hoisted node inside the boundary's (non-root) parent, in position" do
      img = image
      italic = el(Markbridge::AST::Italic, text("after"))
      # image in url in bold: image hoists to right after the url, INSIDE the bold
      tree = doc(el(Markbridge::AST::Bold, url(img), italic))
      normalizer.normalize(tree)

      bold = tree.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.map(&:class)).to eq(
        [Markbridge::AST::Url, Markbridge::AST::Image, Markbridge::AST::Italic],
      )
      expect(bold.children[1]).to be(img) # landed between url and italic, not at root
    end

    it "hoists to the outermost offending ancestor across nested formatting" do
      img = image
      tree = doc(url(el(Markbridge::AST::Bold, img)))
      normalizer.normalize(tree)

      # after the link, not after the bold
      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Image])
      expect(tree.children.last).to be(img)
      # bold emptied → pruned
      expect(tree.descendants(Markbridge::AST::Bold)).to be_empty
    end

    it "preserves document order for several hoists to one boundary" do
      img1 = Markbridge::AST::Image.new(src: "one")
      img2 = Markbridge::AST::Image.new(src: "two")
      tree = doc(url(img1, text("mid"), img2))
      normalizer.normalize(tree)

      link, first, second = tree.children
      expect(link.children.map(&:text)).to eq(["mid"])
      expect([first, second]).to eq([img1, img2]) # order preserved
    end

    it "keeps a relocated subtree's interior intact (destination-stack walk)" do
      inner_quote = el(Markbridge::AST::Quote, text("deep"))
      tree = doc(url(el(Markbridge::AST::Quote, inner_quote)))
      normalizer.normalize(tree)

      hoisted = tree.children.last
      expect(hoisted).to be_a(Markbridge::AST::Quote)
      expect(hoisted.children).to eq([inner_quote]) # inner quote NOT flattened out
    end

    it "hoists a block-level Poll out of an inline container (not just a link)" do
      # Poll renders block-level, so it breaks emphasis with blank lines just
      # like it breaks a link label.
      poll = Markbridge::AST::Poll.new(name: "p")
      tree = doc(el(Markbridge::AST::Bold, text("x"), poll))
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Bold, Markbridge::AST::Poll])
      expect(tree.children.last).to be(poll)
      expect(tree.children.first.children.map(&:class)).to eq([Markbridge::AST::Text])
    end

    it "does not rip an image out of a quote that is itself hoisted from a link" do
      img = image
      tree = doc(url(el(Markbridge::AST::Quote, img)))
      normalizer.normalize(tree)

      hoisted_quote = tree.children.last
      expect(hoisted_quote.children).to eq([img]) # image stays in the quote
    end
  end

  describe "unwrap" do
    it "replaces the inner link with its label, keeping the outer link, and reports it" do
      label = text("click")
      tree = doc(url(url(label, href: "https://b.com"), href: "https://a.com"))
      report = normalizer.normalize(tree)

      outer = tree.children.first
      expect(outer.href).to eq("https://a.com")
      expect(outer.children).to eq([label])
      expect(report).to eq([{ parent: "Url", child: "Url", strategy: :unwrap, count: 1 }])
    end

    it "re-resolves the dissolved children (image inside inner link hoists out)" do
      img = image
      inner = url(text("x"), img, href: "https://b.com")
      tree = doc(url(inner, href: "https://a.com"))
      normalizer.normalize(tree)

      outer, hoisted = tree.children
      expect(outer.href).to eq("https://a.com")
      expect(outer.children.map(&:class)).to eq([Markbridge::AST::Text])
      expect(hoisted).to be(img)
    end

    it "reaches a fixpoint for triple-nested links in one pass" do
      tree = doc(url(url(url(text("deep"), href: "c"), href: "b"), href: "a"))
      first = normalizer.normalize(tree)
      second = normalizer.normalize(tree)

      expect(first).not_to be_empty
      expect(second).to eq([])
      expect(tree.children.size).to eq(1)
      expect(tree.children.first.href).to eq("a")
    end
  end

  describe "textify / drop / splice (custom rules)" do
    it "textifies a subtree to its plain-text projection" do
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Mention,
        strategy: :textify,
      )
      tree = doc(url(text("hi "), Markbridge::AST::Mention.new(name: "alice")))
      report = normalizer.normalize(tree)

      link = tree.children.first
      expect(link.children.size).to eq(1)
      expect(link.children.first.text).to eq("hi @alice")
      expect(report).to eq([{ parent: "Url", child: "Mention", strategy: :textify, count: 1 }])
    end

    it "drops a node entirely and reports it" do
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)
      tree = doc(url(text("label"), image))
      report = normalizer.normalize(tree)

      expect(tree.children.first.children.map(&:class)).to eq([Markbridge::AST::Text])
      expect(report).to eq([{ parent: "Url", child: "Image", strategy: :drop, count: 1 }])
    end

    it "splices in replacement nodes when a callable returns an Array, reported as :replace" do
      replacement = Markbridge::AST::Text.new("[img]")
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: ->(_boundary, _node) { [replacement] },
      )
      tree = doc(url(text("a "), image))
      report = normalizer.normalize(tree)

      # "a " + "[img]" coalesced into one Text
      expect(tree.children.first.children.map(&:text)).to eq(["a [img]"])
      expect(report).to eq([{ parent: "Url", child: "Image", strategy: :replace, count: 1 }])
    end

    it "passes the boundary to a callable strategy" do
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
      tree = doc(link)
      normalizer.normalize(tree)

      expect(seen).to eq([link]) # the offending Url, not nil
    end

    it "raises when a callable resolves to an unknown strategy" do
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: ->(_boundary, _node) { :bogus },
      )
      tree = doc(url(image))

      expect { normalizer.normalize(tree) }.to raise_error(
        ArgumentError,
        /strategy resolved to :bogus/,
      )
    end
  end

  describe "bubble preservation across non-hoist strategies" do
    # A pending hoist (the leading image) must survive when the NEXT sibling
    # is handled by a strategy that returns the accumulated bubble.
    def link_with(strategy)
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Mention, strategy:)
      img = image
      tree = doc(url(img, Markbridge::AST::Mention.new(name: "m")))
      normalizer.normalize(tree)
      [tree, img]
    end

    it "keeps a pending hoist across a :textify sibling" do
      tree, img = link_with(:textify)
      expect(tree.children.last).to be(img)
    end

    it "keeps a pending hoist across a :drop sibling" do
      tree, img = link_with(:drop)
      expect(tree.children.last).to be(img)
    end

    it "keeps a pending hoist across a spliced (callable) sibling" do
      tree, img = link_with(->(_b, _n) { [Markbridge::AST::Text.new("m")] })
      expect(tree.children.last).to be(img)
    end

    it "keeps a pending hoist across an :unwrap of a leaf sibling" do
      tree, img = link_with(:unwrap) # Mention is a leaf → dissolves to nothing
      expect(tree.children.last).to be(img)
    end
  end

  describe "pruning" do
    # Every entry in PRUNE_WHEN_EMPTY, emptied via a custom hoist rule so
    # even the non-inline-container wrappers (Color/Size/Align/Email) are
    # exercised. A missing entry would leave an empty wrapper and fail here.
    prunable = {
      Markbridge::AST::Bold => {
      },
      Markbridge::AST::Italic => {
      },
      Markbridge::AST::Underline => {
      },
      Markbridge::AST::Strikethrough => {
      },
      Markbridge::AST::Superscript => {
      },
      Markbridge::AST::Subscript => {
      },
      Markbridge::AST::Color => {
        color: "red",
      },
      Markbridge::AST::Size => {
        size: "5",
      },
      Markbridge::AST::Align => {
        alignment: "center",
      },
      Markbridge::AST::Email => {
        address: "a@b.c",
      },
    }

    prunable.each do |wrapper, kwargs|
      it "prunes an emptied #{wrapper.name.split("::").last}" do
        custom = hoisting
        custom.rule(parent: wrapper, child: Markbridge::AST::Image, strategy: :hoist_after)
        node = kwargs.empty? ? wrapper.new : wrapper.new(**kwargs)
        node << image
        tree = doc(node)
        custom.normalize(tree)

        expect(tree.descendants(wrapper)).to be_empty
        expect(tree.children.map(&:class)).to eq([Markbridge::AST::Image])
      end
    end

    it "keeps an emptied Url (not prunable) as a bare link" do
      tree = doc(url(image))
      normalizer.normalize(tree)

      expect(tree.children.first).to be_a(Markbridge::AST::Url)
      expect(tree.children.first.children).to eq([])
    end
  end

  # A block ends the line in front of it and starts one after it. An HTML
  # parser trims the whitespace at these line edges, so without the block
  # the two neighbors would touch.
  describe "the place a block was hoisted from" do
    def bold(*children) = el(Markbridge::AST::Bold, *children)
    def list = el(Markbridge::AST::List, el(Markbridge::AST::ListItem, text("x")))
    def code = el(Markbridge::AST::Code, text("a\nb"))

    def texts_after_normalizing(*children)
      tree = doc(bold(*children))
      hoisting.normalize(tree)
      tree.children.first.children.map do |child|
        child.instance_of?(Markbridge::AST::Text) ? child.text : child.class
      end
    end

    it "gets a space when two texts would touch" do
      expect(texts_after_normalizing(text("Run"), code, text("and wait"))).to eq(["Run and wait"])
    end

    it "gets a space for a hoisted list too" do
      expect(texts_after_normalizing(text("a"), list, text("b"))).to eq(["a b"])
    end

    it "gets a space for a hoisted block spoiler" do
      spoiler = el(Markbridge::AST::Spoiler, text("s"), block: true)

      expect(texts_after_normalizing(text("a"), spoiler, text("b"))).to eq(["a b"])
    end

    it "gets a space for a hoisted subclass of a block, of code and of a spoiler" do
      # The report names the classes, so they need a name.
      code_class = stub_const("FencedCode", Class.new(Markbridge::AST::Code))
      list_class = stub_const("TaskList", Class.new(Markbridge::AST::List))
      spoiler_class = stub_const("Fold", Class.new(Markbridge::AST::Spoiler))
      nodes = [
        el(code_class, text("a\nb")),
        el(list_class, el(Markbridge::AST::ListItem, text("x"))),
        el(spoiler_class, text("s"), block: true),
      ]

      nodes.each do |node|
        expect(texts_after_normalizing(text("a"), node, text("b"))).to eq(["a b"])
      end
    end

    it "gets no space when the text in front ends with whitespace" do
      expect(texts_after_normalizing(text("Run\n"), code, text("and"))).to eq(["Run\nand"])
    end

    it "gets no space when the text after it starts with whitespace" do
      expect(texts_after_normalizing(text("Run"), code, text("\u00A0and"))).to eq(["Run\u00A0and"])
    end

    it "gets no space at the start or at the end of the container" do
      expect(texts_after_normalizing(code, text("b"))).to eq(["b"])
      expect(texts_after_normalizing(text("a"), code)).to eq(["a"])
    end

    it "gets one space for two blocks in a row" do
      expect(texts_after_normalizing(text("a"), code, list, text("b"))).to eq(["a b"])
    end

    it "gets a space between two elements, which count as visible" do
      italic = Markbridge::AST::Italic
      result = texts_after_normalizing(el(italic, text("a ")), code, el(italic, text(" b")))

      expect(result).to eq([italic, " ", italic])
    end

    it "gets a space between an element and text without whitespace" do
      italic = Markbridge::AST::Italic

      expect(texts_after_normalizing(el(italic, text("a")), code, text("b"))).to eq([italic, " b"])
      expect(texts_after_normalizing(text("a"), code, el(italic, text("b")))).to eq(["a ", italic])
    end

    it "gets the space only where the block was, not between later nodes" do
      italic = Markbridge::AST::Italic
      result = texts_after_normalizing(text("a"), code, el(italic, text("i")), text("b"))

      expect(result).to eq(["a ", italic, "b"])
    end

    it "gets no space next to a line break" do
      line_break = Markbridge::AST::LineBreak

      expect(texts_after_normalizing(text("a"), line_break.new, code, text("b"))).to eq(
        ["a", line_break, "b"],
      )
      expect(texts_after_normalizing(text("a"), code, line_break.new, text("b"))).to eq(
        ["a", line_break, "b"],
      )
    end

    it "gets no space when the next block is kept and only the one after is text" do
      custom = hoisting
      custom.rule(parent: Markbridge::AST::Bold, child: Markbridge::AST::List, strategy: :drop)
      tree = doc(bold(text("a"), code, list, text("b")))
      custom.normalize(tree)

      expect(tree.children.first.children.map(&:text)).to eq(["a b"])
    end

    it "gets no space for a node that is no block" do
      tree = doc(url(text("a"), image, text("b")))
      normalizer.normalize(tree)

      expect(tree.children.first.children.map(&:text)).to eq(["ab"])
    end

    it "gets a space behind an element that the block was hoisted through" do
      italic = Markbridge::AST::Italic

      expect(texts_after_normalizing(el(italic, text("a"), code), text("b"))).to eq([italic, " b"])
    end

    it "gets a space when the element the block was hoisted through is empty then" do
      italic = Markbridge::AST::Italic

      expect(texts_after_normalizing(text("a"), el(italic, code), text("b"))).to eq(["a b"])
    end

    it "gets a space in front of an element that starts with the block" do
      tree = doc(text("a"), bold(code, text("b")), text("c"))
      hoisting.normalize(tree)

      expect(tree.children.map(&:class)).to eq(
        [
          Markbridge::AST::Text,
          Markbridge::AST::Bold,
          Markbridge::AST::Code,
          Markbridge::AST::Text,
        ],
      )
      expect(tree.children.first.text).to eq("a ")
      expect(tree.children[1].children.map(&:text)).to eq(["b"])
    end

    it "gets a space in front of an element in an element that starts with the block" do
      italic = Markbridge::AST::Italic

      expect(texts_after_normalizing(text("a"), el(italic, code, text("b")))).to eq(["a ", italic])
    end

    it "gets one in front of the outermost element when both start with the block" do
      italic = Markbridge::AST::Italic
      tree = doc(text("a"), bold(el(italic, code, text("b"))))
      hoisting.normalize(tree)

      expect(tree.children.first.text).to eq("a ")
      expect(tree.children[1].children.map(&:class)).to eq([italic])
    end

    it "gets no space in front of an element that is empty then" do
      tree = doc(text("a"), bold(code), text("b"))
      hoisting.normalize(tree)

      expect(tree.children.map(&:class)).to eq(
        [Markbridge::AST::Text, Markbridge::AST::Code, Markbridge::AST::Text],
      )
      expect(tree.children.first.text).to eq("a")
    end

    it "gets no space in front of an element whose block is not at its start" do
      tree = doc(text("a"), bold(text("b"), code))
      hoisting.normalize(tree)

      expect(tree.children.first.text).to eq("a")
    end

    it "gets a space in front of an element that is unwrapped around one that starts with the block" do
      tree = doc(url(text("a"), url(bold(code, text("b")), href: "https://ex.com/2")))
      hoisting.normalize(tree)

      link = tree.children.first
      expect(link.children.map(&:class)).to eq([Markbridge::AST::Text, Markbridge::AST::Bold])
      expect(link.children.first.text).to eq("a ")
    end

    it "gets a space on both sides of the content of a block that is unwrapped" do
      heading = Markbridge::AST::Heading
      inner = el(heading, text("b"), level: 2)
      tree = doc(text("x"), el(heading, text("a"), inner, text("c"), level: 1))
      hoisting.normalize(tree)

      expect(tree.children.first.text).to eq("x")
      expect(tree.children.last.children.map(&:text)).to eq(["a b c"])
    end

    it "gets no space in front of a block that starts with a block that is unwrapped" do
      heading = Markbridge::AST::Heading
      tree = doc(text("x"), el(heading, el(heading, text("b"), level: 2), text("c"), level: 1))
      hoisting.normalize(tree)

      expect(tree.children.first.text).to eq("x")
      expect(tree.children.last.children.map(&:text)).to eq(["b c"])
    end

    it "gets a space around an element whose only content was a block that is unwrapped" do
      heading = Markbridge::AST::Heading
      deletion = el(Markbridge::AST::Deletion, el(heading, text("b"), level: 2))
      outer = el(heading, text("a"), deletion, text("c"), level: 1)
      hoisting.normalize(doc(outer))

      expect(outer.children.map(&:class)).to eq(
        [Markbridge::AST::Text, Markbridge::AST::Deletion, Markbridge::AST::Text],
      )
      expect(outer.children.first.text).to eq("a ")
      expect(outer.children.last.text).to eq(" c")
    end

    it "gets no space between a block that landed and the text behind it" do
      tree = doc(bold(text("a"), code), text("b"))
      hoisting.normalize(tree)

      expect(tree.children.last.text).to eq("b")
    end

    it "gets no space between an element and the block behind it" do
      # A custom rule: with the default rules a block is hoisted, and
      # the block that lands is what stands in front of the next block.
      custom =
        hoisting.rule(
          parent: Markbridge::AST::Bold,
          child: Markbridge::AST::Quote,
          strategy: :unwrap,
        )
      quote = el(Markbridge::AST::Quote, text("q"))
      tree = doc(bold(quote), el(Markbridge::AST::Paragraph, text("p")))
      custom.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Bold, Markbridge::AST::Paragraph])
    end

    it "gets a space behind an element in a block that is unwrapped, when it ended with a block" do
      heading = Markbridge::AST::Heading
      deletion = el(Markbridge::AST::Deletion, el(heading, text("b"), level: 3))
      outer = el(heading, el(heading, deletion, text("c"), level: 2), level: 1)
      hoisting.normalize(doc(outer))

      expect(outer.children.map(&:class)).to eq([Markbridge::AST::Deletion, Markbridge::AST::Text])
      expect(outer.children.last.text).to eq(" c")
    end

    it "gets a space in front of a code span and of an inline spoiler" do
      span = el(Markbridge::AST::Code, text("c"))
      spoiler = el(Markbridge::AST::Spoiler, text("s"))

      expect(texts_after_normalizing(text("a"), list, span)).to eq(["a ", Markbridge::AST::Code])
      expect(texts_after_normalizing(text("a"), list, spoiler)).to eq(
        ["a ", Markbridge::AST::Spoiler],
      )
    end

    it "gets a space behind an element that ended with a block that is unwrapped" do
      heading = Markbridge::AST::Heading
      deletion = el(Markbridge::AST::Deletion, text("x"), el(heading, text("b"), level: 2))
      outer = el(heading, text("a "), deletion, text("c"), level: 1)
      hoisting.normalize(doc(outer))

      expect(deletion.children.map(&:text)).to eq(["x b"])
      expect(outer.children.first.text).to eq("a ")
      expect(outer.children.last.text).to eq(" c")
    end

    it "gets a space in front of an element that started with a block that is unwrapped" do
      heading = Markbridge::AST::Heading
      deletion = el(Markbridge::AST::Deletion, el(heading, text("b"), level: 2), text("x"))
      outer = el(heading, text("a"), deletion, text("c"), level: 1)
      hoisting.normalize(doc(outer))

      expect(deletion.children.map(&:text)).to eq(["b x"])
      expect(outer.children.first.text).to eq("a ")
      expect(outer.children.last.text).to eq("c")
    end

    it "gets no space between a subclass of a block and an element that starts with the block" do
      quote_class = stub_const("PullQuote", Class.new(Markbridge::AST::Quote))
      tree = doc(el(quote_class, text("q")), bold(code, text("b")))
      hoisting.normalize(tree)

      expect(tree.children.map(&:class)).to eq(
        [quote_class, Markbridge::AST::Bold, Markbridge::AST::Code],
      )
    end

    it "gets no space between a block spoiler and an element that starts with the block" do
      spoiler = el(Markbridge::AST::Spoiler, text("s"), block: true)
      tree = doc(spoiler, bold(code, text("b")))
      hoisting.normalize(tree)

      expect(tree.children.map(&:class)).to eq(
        [Markbridge::AST::Spoiler, Markbridge::AST::Bold, Markbridge::AST::Code],
      )
    end

    it "gets a space between a code span and an element that starts with the block" do
      span = el(Markbridge::AST::Code, text("c"))
      tree = doc(span, bold(code, text("b")))
      hoisting.normalize(tree)

      expect(tree.children.map(&:class)).to eq(
        [
          Markbridge::AST::Code,
          Markbridge::AST::Text,
          Markbridge::AST::Bold,
          Markbridge::AST::Code,
        ],
      )
    end

    it "gets no space around the content of a link that is unwrapped" do
      tree = doc(url(text("a"), url(text("b"), href: "https://ex.com/2"), text("c")))
      hoisting.normalize(tree)

      expect(tree.children.first.children.map(&:text)).to eq(["abc"])
    end

    it "gets no space between the items of a list, the rows of a table and the cells of a row" do
      item = Markbridge::AST::ListItem
      cell = Markbridge::AST::TableCell
      row = Markbridge::AST::TableRow
      # A custom rule, so the code leaves its item, its row or its cell.
      leaving = ->(parent) do
        hoisting.rule(parent:, child: Markbridge::AST::Code, strategy: :hoist_after)
      end
      list = el(Markbridge::AST::List, el(item, bold(text("a"), code)), el(item, text("b")))
      cells = el(row, el(cell, bold(text("a"), code)), el(cell, text("b")))
      rows = el(Markbridge::AST::Table, el(row, el(cell, bold(code))), el(row, el(cell, text("b"))))

      leaving.call(item).normalize(doc(list))
      leaving.call(cell).normalize(doc(el(Markbridge::AST::Table, cells)))
      leaving.call(row).normalize(doc(rows))

      expect(list.children.map(&:class)).to eq([item, Markbridge::AST::Code, item])
      expect(cells.children.map(&:class)).to eq([cell, Markbridge::AST::Code, cell])
      expect(rows.children.map(&:class)).to eq([row, Markbridge::AST::Code, row])
    end

    it "gets no space behind an element that a node that is no block was hoisted through" do
      italic = Markbridge::AST::Italic
      tree = doc(url(el(italic, text("a"), image), text("b")))
      normalizer.normalize(tree)

      expect(tree.children.first.children.map(&:class)).to eq([italic, Markbridge::AST::Text])
      expect(tree.children.first.children.last.text).to eq("b")
    end
  end

  describe "a block that leaves a block that leaves its place too" do
    def bold(*children) = el(Markbridge::AST::Bold, *children)

    it "goes on upward behind a node that landed, when its own boundary is further up" do
      italic = el(Markbridge::AST::Italic, url(image, el(Markbridge::AST::Code, text("a\nb"))))
      tree = doc(italic)

      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Italic, Markbridge::AST::Code])
      expect(italic.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Image])
    end

    it "lands behind the block it was in" do
      table =
        el(
          Markbridge::AST::Table,
          el(Markbridge::AST::TableRow, el(Markbridge::AST::TableCell, text("t"))),
        )
      quote = el(Markbridge::AST::Quote, text("q"))
      heading = el(Markbridge::AST::Heading, text("h"), table, quote, level: 2)
      tree = doc(el(Markbridge::AST::Paragraph, bold(text("a"), heading), text("b")), text("end"))

      hoisting.normalize(tree)

      paragraph = tree.children.first
      expect(paragraph.children.map(&:class)).to eq(
        [
          Markbridge::AST::Bold,
          Markbridge::AST::Heading,
          Markbridge::AST::Table,
          Markbridge::AST::Quote,
          Markbridge::AST::Text,
        ],
      )
      expect(paragraph.children[1].children.map(&:text)).to eq(["h"])
      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Paragraph, Markbridge::AST::Text])
    end
  end

  describe "copy-on-write" do
    it "leaves unchanged children as the same objects and only rewrites what moved" do
      keep_a = el(Markbridge::AST::Bold, text("a"))
      keep_b = el(Markbridge::AST::Italic, text("b"))
      img = image
      link = url(keep_a, img, keep_b) # image between two non-mergeable wrappers
      tree = doc(link)
      normalizer.normalize(tree)

      expect(tree.children.first).to be(link)
      expect(tree.children.first.children).to eq([keep_a, keep_b])
      expect(tree.children.first.children.first).to be(keep_a)
      expect(tree.children.first.children.last).to be(keep_b)
      expect(tree.children.last).to be(img)
    end

    it "keeps the unchanged prefix when divergence happens after the first child" do
      # text at index 0 is kept (no divergence yet); the image at index 1
      # hoists, so the copied prefix must be exactly [text].
      keep = text("keep")
      img = image
      link = url(keep, img)
      tree = doc(link)
      normalizer.normalize(tree)

      expect(link.children).to eq([keep])
      expect(link.children.first).to be(keep)
      expect(tree.children.last).to be(img)
    end

    it "keeps the unchanged prefix when a kept child diverges after the first child" do
      # text is kept at index 0 (no divergence); the bold at index 1 is a kept
      # child that diverges (its image hoists, emptying it), so the copied
      # prefix must be exactly [text] and the emptied bold pruned away.
      keep = text("keep")
      img = image
      link = url(keep, el(Markbridge::AST::Bold, img))
      tree = doc(link)
      normalizer.normalize(tree)

      expect(link.children).to eq([keep])
      expect(link.children.first).to be(keep)
      expect(tree.children.last).to be(img)
    end

    it "pops each element off the shared stack so a later sibling sees no stale ancestor" do
      # url_a is a sibling of the bold, not an ancestor of url_b. If url_a were
      # left on the stack, url_b would resolve (Url, Url) and be unwrapped.
      inner = url(text("b"), href: "https://b.com")
      bold = el(Markbridge::AST::Bold, inner)
      tree = doc(url(text("a"), href: "https://a.com"), bold)
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Bold])
      expect(bold.children.first).to be(inner) # url_b intact, not unwrapped
    end

    it "does not touch a violation-free tree at all (same child arrays)" do
      inner = text("hello")
      bold = el(Markbridge::AST::Bold, inner)
      tree = doc(bold)
      before = tree.children
      report = normalizer.normalize(tree)

      expect(report).to eq([])
      expect(tree.children).to be(before) # array identity: never replaced
      expect(bold.children.first).to be(inner)
    end
  end

  describe "coalescing" do
    it "merges adjacent MarkdownText produced by an unwrap" do
      md1 = Markbridge::AST::MarkdownText.new("**a**")
      md2 = Markbridge::AST::MarkdownText.new("**b**")
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      tree = doc(url(el(Markbridge::AST::Bold, md1, md2)))
      normalizer.normalize(tree)

      link = tree.children.first
      expect(link.children.size).to eq(1)
      expect(link.children.first).to be_a(Markbridge::AST::MarkdownText)
      expect(link.children.first.text).to eq("**a****b**")
    end

    it "does not merge a Text next to a MarkdownText" do
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      tree =
        doc(
          url(
            el(Markbridge::AST::Bold, text("plain"), Markbridge::AST::MarkdownText.new("**md**")),
          ),
        )
      normalizer.normalize(tree)

      link = tree.children.first
      expect(link.children.map(&:class)).to eq(
        [Markbridge::AST::Text, Markbridge::AST::MarkdownText],
      )
    end

    it "does not merge a MarkdownText followed by a plain Text" do
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      tree =
        doc(
          url(
            el(Markbridge::AST::Bold, Markbridge::AST::MarkdownText.new("**md**"), text("plain")),
          ),
        )
      normalizer.normalize(tree)

      expect(tree.children.first.children.map(&:class)).to eq(
        [Markbridge::AST::MarkdownText, Markbridge::AST::Text],
      )
    end

    it "does not merge (or crash on) a non-text node adjacent to a Text" do
      # common_mark has no (Url, Image) rule, so the image survives the unwrap
      # and lands next to the text — mergeable? must reject the pair.
      unwrapper = hoisting
      unwrapper.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      img = image
      tree = doc(url(el(Markbridge::AST::Bold, img, text("x"))))

      expect { unwrapper.normalize(tree) }.not_to raise_error
      expect(tree.children.first.children.map(&:class)).to eq(
        [Markbridge::AST::Image, Markbridge::AST::Text],
      )
    end
  end

  describe "ancestor stack ordering and destination" do
    it "picks the outermost boundary when a node is inside two matching ancestors" do
      # quote inside a link inside a heading: (Heading, Quote) and (Url, Quote)
      # both match; the outermost (Heading) wins, so the quote lands at the
      # document level after the heading — not inside it after the link.
      heading = el(Markbridge::AST::Heading, url(el(Markbridge::AST::Quote, text("q"))), level: 1)
      tree = doc(heading)
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Heading, Markbridge::AST::Quote])
    end

    it "walks a hoisted subtree against the ancestors above its boundary" do
      # (Url, Quote) hoists the quote out of the link; a custom (Spoiler, Image)
      # rule must still fire on the image inside that quote, which is only
      # possible if the destination stack still contains the Spoiler ancestor.
      # (A spoiler is used because, unlike an inline container, it has no block
      # rule of its own, so the quote's boundary stays at the Url.)
      custom = hoisting
      custom.rule(
        parent: Markbridge::AST::Spoiler,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      img = image
      spoiler = el(Markbridge::AST::Spoiler, url(el(Markbridge::AST::Quote, img)))
      tree = doc(spoiler)
      custom.normalize(tree)

      # image escaped the quote entirely (destination stack retained Spoiler)
      quote = tree.descendants(Markbridge::AST::Quote).first
      expect(quote.descendants(Markbridge::AST::Image)).to be_empty
      expect(tree.descendants(Markbridge::AST::Image)).to contain_exactly(img)
    end

    it "retains the root in the destination stack (a document-boundary rule fires on deep content)" do
      # (Url, Quote) hoists the quote out of the link; a custom (Document, Image)
      # rule must still fire on the image inside that quote, which requires the
      # destination stack to still contain the Document (root) ancestor.
      custom = hoisting
      custom.rule(
        parent: Markbridge::AST::Document,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      img = image
      tree = doc(url(el(Markbridge::AST::Quote, img)))
      custom.normalize(tree)

      quote = tree.descendants(Markbridge::AST::Quote).first
      expect(quote.descendants(Markbridge::AST::Image)).to be_empty
      expect(tree.children.last).to be(img) # escaped all the way to the document
    end

    it "lands a propagated hoist after its boundary, not at the very end" do
      # image → boundary is the link; a trailing sibling must stay after it.
      img = image
      tail = el(Markbridge::AST::Italic, text("tail"))
      tree = doc(url(el(Markbridge::AST::Bold, img)), tail)
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq(
        [Markbridge::AST::Url, Markbridge::AST::Image, Markbridge::AST::Italic],
      )
      expect(tree.children[1]).to be(img)
    end
  end

  describe "inline-code predicate through the walker" do
    it "keeps an inline code span in a link" do
      code = el(Markbridge::AST::Code, text("x"))
      tree = doc(url(code))
      normalizer.normalize(tree)

      expect(tree.children.first.children).to eq([code])
    end

    it "hoists a multi-line code block out of a link" do
      code = el(Markbridge::AST::Code, text("a\nb"))
      tree = doc(url(code))
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Code])
    end

    it "hoists a multi-line code block out of an inline container that is not a link" do
      code = el(Markbridge::AST::Code, text("a\nb"))
      tree = doc(el(Markbridge::AST::Bold, code))
      normalizer.normalize(tree)

      # bold emptied → pruned; the block lands at the top level
      expect(tree.descendants(Markbridge::AST::Bold)).to be_empty
      expect(tree.children).to eq([code])
    end

    it "keeps an inline code span inside bold" do
      code = el(Markbridge::AST::Code, text("x"))
      tree = doc(el(Markbridge::AST::Bold, code))
      normalizer.normalize(tree)

      expect(tree.children.first).to be_a(Markbridge::AST::Bold)
      expect(tree.children.first.children).to eq([code])
    end
  end

  describe "unwrap edge cases" do
    it "keeps a leaf targeted by an unwrap rule and does not report a no-op" do
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Mention,
        strategy: :unwrap,
      )
      mention = Markbridge::AST::Mention.new(name: "x")
      tree = doc(url(text("a"), mention))
      report = normalizer.normalize(tree)

      expect(tree.children.first.children.map(&:class)).to eq(
        [Markbridge::AST::Text, Markbridge::AST::Mention],
      )
      expect(tree.children.first.children.last).to be(mention) # kept, not dropped
      expect(report).to eq([]) # unwrap of a leaf is a silent no-op
    end

    it "resolves a callable rule on a dissolved (unwrapped) child, reporting the boundary" do
      # unwrap the bold; the code block it held must then be hoisted out of the
      # link by the (Url, Code) callable — exercised via the unwrap recursion.
      # The reported parent must be the Url boundary, not nil.
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      tree = doc(url(el(Markbridge::AST::Bold, el(Markbridge::AST::Code, text("a\nb")))))
      report = normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Code])
      expect(report).to include({ parent: "Url", child: "Code", strategy: :hoist_after, count: 1 })
    end

    it "passes the real boundary to a callable resolved on a dissolved child" do
      seen = []
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy:
          lambda do |boundary, _node|
            seen << boundary
            :drop
          end,
      )
      link = url(el(Markbridge::AST::Bold, image))
      normalizer.normalize(doc(link))

      expect(seen).to eq([link]) # the Url boundary, not nil
    end

    it "lands a hoist raised inside a dissolved child after that child" do
      # (Color, Bold) unwrap dissolves the bold; the inner link keeps its
      # image hoist landing right after the link, inside the Color — the
      # dissolved child (the link) is itself the boundary.
      custom = hoisting
      custom.rule(parent: Markbridge::AST::Color, child: Markbridge::AST::Bold, strategy: :unwrap)
      custom.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      img = image
      color = el(Markbridge::AST::Color, el(Markbridge::AST::Bold, url(img)), color: "red")
      custom.normalize(doc(color))

      expect(color.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Image])
      expect(color.children.last).to be(img)
    end

    it "preserves multiple hoists raised while dissolving one child" do
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      img1 = Markbridge::AST::Image.new(src: "one")
      img2 = Markbridge::AST::Image.new(src: "two")
      tree = doc(url(el(Markbridge::AST::Bold, img1, img2)))
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq(
        [Markbridge::AST::Url, Markbridge::AST::Image, Markbridge::AST::Image],
      )
      expect(tree.children[1, 2]).to eq([img1, img2]) # both images, in order
    end

    it "keeps a dissolved child that resolves to :keep (not routed to emit)" do
      # unwrap the bold; the mention it held resolves to an explicit :keep and
      # must be appended, not sent through emit (which would raise on :keep).
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Mention,
        strategy: :keep,
      )
      tree = doc(url(el(Markbridge::AST::Bold, Markbridge::AST::Mention.new(name: "x"))))

      expect { normalizer.normalize(tree) }.not_to raise_error
      expect(tree.children.first.children.map(&:class)).to eq([Markbridge::AST::Mention])
    end

    it "preserves an earlier sibling's hoist across a later unwrap" do
      # image hoists first; then the bold unwraps — the pending [image] bubble
      # must survive into the unwrap, not be dropped.
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      img = image
      tree = doc(url(img, el(Markbridge::AST::Bold, text("k"))))
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Image])
      expect(tree.children.last).to be(img)
      expect(tree.children.first.children.map(&:text)).to eq(["k"])
    end

    it "preserves a hoist raised while dissolving, across the remaining children" do
      # image (first dissolved child) hoists; the following text must not drop
      # its pending bubble.
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Bold, strategy: :unwrap)
      img = image
      tree = doc(url(el(Markbridge::AST::Bold, img, text("k"))))
      normalizer.normalize(tree)

      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Url, Markbridge::AST::Image])
      expect(tree.children.last).to be(img)
      expect(tree.children.first.children.map(&:text)).to eq(["k"])
    end
  end

  describe "root-level bubble (defensive)" do
    it "appends a node hoisted with the document as its boundary" do
      # A (Document, Image) rule makes the document the hoist boundary; the
      # bubble reaches the root and Walker#call must append it (not drop it).
      custom = hoisting
      custom.rule(
        parent: Markbridge::AST::Document,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )
      img = image
      tree = doc(img, text("b"))
      custom.normalize(tree)

      # image removed from the front, appended at the end by the root fallback
      expect(tree.children.map(&:class)).to eq([Markbridge::AST::Text, Markbridge::AST::Image])
      expect(tree.children.last).to be(img)
    end
  end
end
