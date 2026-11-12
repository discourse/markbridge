# frozen_string_literal: true

RSpec.describe Markbridge::Normalizer::Carrier do
  ast = Markbridge::AST

  def el(klass, *children, **kwargs)
    node = kwargs.empty? ? klass.new : klass.new(**kwargs)
    children.each { |child| node << child }
    node
  end

  def text(string) = Markbridge::AST::Text.new(string)

  # The tree as nested arrays of class names and texts.
  def shape(node)
    return node.text if node.respond_to?(:text)

    name = node.class.name.split("::").last
    node.is_a?(Markbridge::AST::Element) ? [name, *node.children.map { |c| shape(c) }] : name
  end

  let(:bold) { el(ast::Bold, text("inside the bold")) }
  let(:copies) { [] }

  def carry(block, *wrappers)
    described_class.call(block, wrappers, copies)
    shape(block)
  end

  it "puts a copy of the wrapper around the text of a paragraph" do
    paragraph = el(ast::Paragraph, text("a"), el(ast::Italic, text("b")))

    expect(carry(paragraph, bold)).to eq(["Paragraph", ["Bold", "a", %w[Italic b]]])
    expect(paragraph.children.first).not_to equal(bold)
    expect(shape(bold)).to eq(["Bold", "inside the bold"])
  end

  it "puts it around the text of a heading and of their subclasses" do
    heading = el(ast::Heading, text("h"), level: 2)
    lead = el(stub_const("Lead", Class.new(ast::Paragraph)), text("p"))

    expect(carry(heading, bold)).to eq(["Heading", %w[Bold h]])
    expect(carry(lead, bold)).to eq(["Lead", %w[Bold p]])
  end

  it "nests the copies like the wrappers were, the first one outside" do
    link = el(ast::Url, href: "https://example.com")
    color = el(ast::Color, color: "red")
    paragraph = el(ast::Paragraph, text("a"))

    expect(carry(paragraph, link, color, bold)).to eq(["Paragraph", ["Url", ["Color", %w[Bold a]]]])
    copy = paragraph.children.first
    expect(copy.href).to eq("https://example.com")
    expect(copy.children.first.color).to eq("red")
  end

  it "gives every copy it makes to the list it was called with" do
    quote = el(ast::Quote, text("a"), el(ast::Paragraph, text("b")))

    carry(quote, el(ast::Italic), bold)

    expect(copies.map(&:class)).to contain_exactly(ast::Bold, ast::Italic, ast::Bold, ast::Italic)
    expect(copies).to include(quote.children.first, quote.children.first.children.first)
  end

  it "leaves the block as it is without a wrapper" do
    paragraph = el(ast::Paragraph, text("a"))
    quote = el(ast::Quote, text("b"), el(ast::Paragraph, text("c")))

    expect(carry(paragraph)).to eq(%w[Paragraph a])
    expect(carry(quote)).to eq(["Quote", "b", %w[Paragraph c]])
    expect(copies).to eq([])
  end

  it "wraps each run of text between the blocks of a quote, and goes into the blocks" do
    list = el(ast::List, el(ast::ListItem, text("b")), el(ast::ListItem, text("c")))
    quote = el(ast::Quote, text("a"), el(ast::Italic, text("i")), list, text("d"))

    expect(carry(quote, bold)).to eq(
      [
        "Quote",
        ["Bold", "a", %w[Italic i]],
        ["List", ["ListItem", %w[Bold b]], ["ListItem", %w[Bold c]]],
        %w[Bold d],
      ],
    )
  end

  it "goes through a table to its cells" do
    cell = el(ast::TableCell, text("c"))
    table = el(ast::Table, el(ast::TableRow, cell))

    expect(carry(table, bold)).to eq(["Table", ["TableRow", ["TableCell", %w[Bold c]]]])
  end

  [
    [ast::Details, {}],
    [ast::Align, { alignment: "center" }],
    [ast::Spoiler, { block: true }],
    [ast::ListItem, {}],
    [ast::TableRow, {}],
  ].each do |klass, kwargs|
    it "wraps the text in a #{klass.name.split("::").last}" do
      block = el(klass, text("a"), **kwargs)

      carry(block, bold)

      expect(shape(block.children.first)).to eq(%w[Bold a])
    end
  end

  it "wraps the text in a subclass of a block" do
    block = el(stub_const("PullQuote", Class.new(ast::Quote)), text("a"))

    expect(carry(block, bold)).to eq(["PullQuote", %w[Bold a]])
  end

  it "leaves code and other blocks without text alone" do
    code = el(ast::Code, text("a\nb"), block: true)
    rule = ast::HorizontalRule.new
    quote = el(ast::Quote, code, rule)

    expect(carry(quote, bold)).to eq(["Quote", ["Code", "a\nb"], "HorizontalRule"])
    expect(carry(code, bold)).to eq(["Code", "a\nb"])
    expect(copies).to eq([])
  end

  it "takes a code span, an inline spoiler and an image into the run" do
    span = el(ast::Code, text("c"))
    spoiler = el(ast::Spoiler, text("s"))
    image = ast::Image.new(src: "https://example.com/i.png")
    quote = el(ast::Quote, span, spoiler, image)

    expect(carry(quote, bold)).to eq(["Quote", ["Bold", %w[Code c], %w[Spoiler s], ["Image"]]])
  end

  it "wraps a run that is one image, which is no text but shows" do
    quote = el(ast::Quote, ast::Image.new(src: "https://example.com/i.png"))

    expect(carry(quote, bold)).to eq(["Quote", ["Bold", ["Image"]]])
  end

  it "leaves a run of whitespace as it is, and an empty block" do
    quote = el(ast::Quote, text(" \n"), el(ast::Paragraph, text("p")), text(" "))
    empty = el(ast::Paragraph)

    expect(carry(quote, bold)).to eq(["Quote", " \n", ["Paragraph", %w[Bold p]], " "])
    expect(carry(empty, bold)).to eq(["Paragraph"])
  end

  it "wraps a run with a space and a word in it" do
    paragraph = el(ast::Paragraph, text(" a"))

    expect(carry(paragraph, bold)).to eq(["Paragraph", ["Bold", " a"]])
  end
end
