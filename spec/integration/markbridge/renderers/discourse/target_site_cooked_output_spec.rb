# frozen_string_literal: true

# What a reader sees on a site without a plugin: the plain forms the
# renderer writes with a feature off are Markdown, so plain markdown-it
# cooks them. With the feature on, the BBCode is text to plain
# markdown-it; the real Discourse engine would cook it.
RSpec.describe "cooked output per target site", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  let(:without_plugins) do
    Markbridge.discourse_renderer(
      features: {
        details: false,
        spoiler: false,
        poll: false,
        post_event: false,
      },
    )
  end

  def document(*nodes)
    document = Markbridge::AST::Document.new
    nodes.each { |node| document << node }
    document
  end

  def cook_without_plugins(document)
    fragment(cook_markdown(Markbridge.render(document, renderer: without_plugins).markdown))
  end

  def text(value)
    Markbridge::AST::Text.new(value)
  end

  it "writes a details block as its title in bold and its content" do
    details = Markbridge::AST::Details.new(title: "Show more") << text("hidden body")

    cooked = cook_without_plugins(document(text("before"), details, text("after")))

    expect(cooked.css("p").map(&:text)).to eq(["before", "Show more", "hidden body", "after"])
    expect(cooked.at_css("p:nth-child(2) > strong").text).to eq("Show more")
    expect(cooked.css("details")).to be_empty
  end

  it "writes a spoiler as its text with the title in front" do
    spoiler = Markbridge::AST::Spoiler.new(title: "Reveal") << text("hidden")

    cooked = cook_without_plugins(document(text("see "), spoiler))

    expect(cooked.at_css("p").text).to eq("see Reveal: hidden")
  end

  it "writes a poll as a list of its options" do
    poll = Markbridge::AST::Poll.new(options: ["Yes", "No *way*"])

    cooked = cook_without_plugins(document(text("vote"), poll))

    expect(cooked.css("ul > li").map(&:text)).to eq(["Yes", "No *way*"])
    expect(cooked.css("li > p")).to be_empty
  end

  it "writes an event as a paragraph with the name and the dates" do
    event =
      Markbridge::AST::Event.new(name: "Meetup", starts_at: "2026-01-01", ends_at: "2026-01-02")

    cooked = cook_without_plugins(document(event, text("after")))

    expect(cooked.css("p").map(&:text)).to eq(["Meetup, 2026-01-01 to 2026-01-02", "after"])
  end

  describe "a list next to a plain form that starts or ends with a list" do
    def list(*items)
      list = Markbridge::AST::List.new
      items.each { |item| list << (Markbridge::AST::ListItem.new << text(item)) }
      list
    end

    def poll(*options)
      Markbridge::AST::Poll.new(options:)
    end

    def item_lists(nodes)
      cook_without_plugins(document(*nodes)).css("ul").map { |ul| ul.css("li").map(&:text) }
    end

    it "keeps a list apart from the details block in front of it that ends with a list" do
      details = Markbridge::AST::Details.new(title: "More") << list("a")

      expect(item_lists([details, list("b")])).to eq([["a"], ["b"]])
    end

    it "keeps a list apart from the details block after it that starts with a list" do
      details = Markbridge::AST::Details.new << list("b")

      expect(item_lists([list("a"), details])).to eq([["a"], ["b"]])
    end

    it "keeps the options of a poll apart from the lists around it" do
      expect(item_lists([list("a"), poll("x", "y"), list("b")])).to eq([["a"], %w[x y], ["b"]])
    end

    it "keeps the options of two polls apart" do
      expect(item_lists([poll("x"), poll("y")])).to eq([["x"], ["y"]])
    end
  end

  it "keeps the BBCode of a bundled plugin by default, as text to plain markdown-it" do
    details = Markbridge::AST::Details.new(title: "Show more") << text("hidden body")

    cooked = fragment(cook_ast(document(details)))

    expect(cooked.text).to include("[details=").and include("[/details]")
  end
end
