# frozen_string_literal: true

require "nokogiri"

# Where two siblings meet, the renderer puts an empty HTML comment between
# their delimiters when the Markdown parser would read them wrong (the
# JOIN_ACTIONS rules in Renderer). Some of these comments are only needed
# for cmark-gfm, which does not count a `~` as punctuation next to an
# emphasis delimiter. markdown-it does, so there the comment has to change
# nothing. Every case is checked on the cooked HTML, with both cookers.
RSpec.describe "emphasis join cooked output" do
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
    Nokogiri::HTML5.fragment(cook(Markbridge.render(document).markdown)).at_css("p")
  end

  # The cooked paragraph: each [selector, text] pair, then all of its text.
  def expect_cooked(cooked, elements, text:)
    found = elements.map { |selector, _| [selector, cooked.at_css(selector)&.text] }

    expect(found).to eq(elements), cooked.to_html
    expect(cooked.text).to eq(text)
  end

  shared_examples "sibling joins" do
    it "closes bold that ends with punctuation in front of strikethrough" do
      cooked = paragraph(node(:Bold, "a*"), node(:Strikethrough, "b"))

      expect_cooked(cooked, [%w[strong a*], ["s, del", "b"]], text: "a*b")
    end

    it "opens emphasis that starts with punctuation after strikethrough" do
      cooked = paragraph(node(:Strikethrough, "a"), node(:Italic, "#"))

      expect_cooked(cooked, [["s, del", "a"], %w[em #]], text: "a#")
    end

    it "closes strikethrough that ends with punctuation in front of a word" do
      cooked = paragraph(node(:Strikethrough, "a!"), node(:Text, "b"))

      expect_cooked(cooked, [["s, del", "a!"]], text: "a!b")
    end

    it "opens strikethrough that starts with punctuation after a word" do
      cooked = paragraph(node(:Text, "w"), node(:Strikethrough, "# heading"))

      expect_cooked(cooked, [["s, del", "# heading"]], text: "w# heading")
    end

    it "keeps bold and strikethrough apart when no punctuation is at the edge" do
      cooked = paragraph(node(:Bold, "a"), node(:Strikethrough, "b"))

      expect_cooked(cooked, [%w[strong a], ["s, del", "b"]], text: "ab")
    end

    it "keeps two strikethroughs apart" do
      cooked = paragraph(node(:Strikethrough, "a"), node(:Strikethrough, "b"))

      expect(cooked.css("s, del").map(&:text)).to eq(%w[a b])
    end

    it "closes bold that ends with punctuation in front of a word" do
      cooked = paragraph(node(:Bold, "*bold*"), node(:Text, "tail"))

      expect_cooked(cooked, [%w[strong *bold*]], text: "*bold*tail")
    end
  end

  context "with markdown-it", skip: MarkdownItCooker::SKIP_REASON do
    def cook(markdown)
      MarkdownItCooker.cook(markdown)
    end

    include_examples "sibling joins"

    it "leaves single tildes in text as text" do
      cooked = paragraph(node(:Text, "a ~b~ c"))

      expect_cooked(cooked, [["s, del", nil]], text: "a ~b~ c")
    end
  end

  # cmark-gfm also reads a single `~` pair as strikethrough. The renderer
  # escapes only `~~`, like markdown-it needs it, so `a ~b~ c` in a Text
  # node cooks to <del> here.
  context "with commonmarker", skip: CookedOutput::SKIP_REASON do
    def cook(markdown)
      Commonmarker.to_html(markdown, options: CookedOutput::OPTIONS)
    end

    include_examples "sibling joins"
  end
end
