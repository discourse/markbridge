# frozen_string_literal: true

# Where two siblings meet, the serializer puts an empty HTML comment
# between their delimiters when the Markdown parser would read them wrong
# (see Inline::Joins). Every case is checked on the cooked HTML: the
# emphasis and the strikethrough come out as elements with the right
# text, and nothing else shows.
RSpec.describe "emphasis join cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  # @param name [Symbol] an AST class, :Text for a Text node
  def node(name, text)
    return Markbridge::AST::Text.new(text) if name == :Text

    element = Markbridge::AST.const_get(name).new
    element << Markbridge::AST::Text.new(text)
    element
  end

  def paragraph(*nodes)
    document = Markbridge::AST::Document.new
    nodes.each { |child| document << child }
    fragment(cook_ast(document)).at_css("p")
  end

  # The cooked paragraph: each [selector, text] pair, then all of its text.
  def expect_cooked(cooked, elements, text:)
    found = elements.map { |selector, _| [selector, cooked.at_css(selector)&.text] }

    expect(found).to eq(elements), cooked.to_html
    expect(cooked.text).to eq(text)
  end

  it "closes bold that ends with punctuation in front of strikethrough" do
    cooked = paragraph(node(:Bold, "a*"), node(:Strikethrough, "b"))

    expect_cooked(cooked, [%w[strong a*], %w[s b]], text: "a*b")
  end

  it "opens emphasis that starts with punctuation after strikethrough" do
    cooked = paragraph(node(:Strikethrough, "a"), node(:Italic, "#"))

    expect_cooked(cooked, [%w[s a], %w[em #]], text: "a#")
  end

  it "closes strikethrough that ends with punctuation in front of a word" do
    cooked = paragraph(node(:Strikethrough, "a!"), node(:Text, "b"))

    expect_cooked(cooked, [%w[s a!]], text: "a!b")
  end

  it "opens strikethrough that starts with punctuation after a word" do
    cooked = paragraph(node(:Text, "w"), node(:Strikethrough, "# heading"))

    expect_cooked(cooked, [["s", "# heading"]], text: "w# heading")
  end

  it "keeps bold and strikethrough apart when no punctuation is at the edge" do
    cooked = paragraph(node(:Bold, "a"), node(:Strikethrough, "b"))

    expect_cooked(cooked, [%w[strong a], %w[s b]], text: "ab")
  end

  it "keeps two strikethroughs apart" do
    cooked = paragraph(node(:Strikethrough, "a"), node(:Strikethrough, "b"))

    expect(cooked.css("s").map(&:text)).to eq(%w[a b])
  end

  it "closes bold that ends with punctuation in front of a word" do
    cooked = paragraph(node(:Bold, "*bold*"), node(:Text, "tail"))

    expect_cooked(cooked, [%w[strong *bold*]], text: "*bold*tail")
  end

  it "leaves single tildes in text as text" do
    cooked = paragraph(node(:Text, "a ~b~ c"))

    expect_cooked(cooked, [["s", nil]], text: "a ~b~ c")
  end
end
