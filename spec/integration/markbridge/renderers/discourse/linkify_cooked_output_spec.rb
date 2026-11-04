# frozen_string_literal: true

require "nokogiri"

# A bare URL in the Markdown is linked by the Markdown parser, not by the
# renderer: markdown-it's linkify in Discourse. UrlTag writes the URL bare
# only where linkify links it and writes `[url](url)` everywhere else.
# Each case is checked on the cooked anchor.
RSpec.describe "bare URL cooked output", skip: MarkdownItCooker::SKIP_REASON do
  def cook(markdown)
    MarkdownItCooker.cook(markdown)
  end

  BARE_URL = "https://example.com/t/5"
  BARE_PAREN_URL = "https://example.com/a_(b)"

  # +bbcode+ with each {url} replaced by a link whose text is the href,
  # which is how a bare URL looks in the AST.
  def markdown(bbcode, href: BARE_URL)
    Markbridge.bbcode_to_markdown(bbcode.gsub("{url}", "[url=#{href}]#{href}[/url]")).markdown
  end

  def paragraph(bbcode, href: BARE_URL)
    Nokogiri::HTML5.fragment(cook(markdown(bbcode, href:))).at_css("p")
  end

  def links(cooked)
    cooked.css("a").map { |a| [a["href"], a.text] }
  end

  # The URL is the only link, it points to +href+ and its text is +href+;
  # the paragraph keeps the text around it as +text+.
  def expect_linked(bbcode, text:, href: BARE_URL)
    cooked = paragraph(bbcode, href:)

    expect(links(cooked)).to eq([[href, href]]), cooked.to_html
    expect(cooked.text).to eq(text)
  end

  context "when whitespace stands around the URL" do
    let(:bbcode) { "see {url} now" }

    it "links it" do
      expect_linked(bbcode, text: "see #{BARE_URL} now")
    end

    it "keeps it a bare URL in the Markdown" do
      expect(markdown(bbcode)).to eq("see #{BARE_URL} now")
    end
  end

  it "links a URL that is all there is" do
    expect_linked("{url}", text: BARE_URL)
    expect(markdown("{url}")).to eq(BARE_URL)
  end

  # The punctuation linkify leaves out of the link.
  %w[. , ! ? ) .. ... !! ?? ). ),].each do |punctuation|
    context "when #{punctuation} follows the URL" do
      it "leaves the #{punctuation} out of the link before whitespace" do
        bbcode = "see {url}#{punctuation} now"

        expect_linked(bbcode, text: "see #{BARE_URL}#{punctuation} now")
        expect(markdown(bbcode)).not_to include("](")
      end

      it "leaves the #{punctuation} out of the link at the end of the text" do
        expect_linked("see {url}#{punctuation}", text: "see #{BARE_URL}#{punctuation}")
      end
    end
  end

  # markdown-it keeps a `:` and the first character of a mixed run in the
  # link, so the URL is written as a Markdown link.
  %w[: .) ?! ., ,, ;].each do |punctuation|
    it "keeps #{punctuation} after the URL out of the link" do
      bbcode = "see {url}#{punctuation} now"

      expect_linked(bbcode, text: "see #{BARE_URL}#{punctuation} now")
      expect(markdown(bbcode)).to include("](")
    end
  end

  it "links a URL with ( in front" do
    bbcode = "see ({url}) now"

    expect_linked(bbcode, text: "see (#{BARE_URL}) now")
    expect(markdown(bbcode)).not_to include("](")
  end

  context "when the URL is glued to text" do
    it "links it with text in front" do
      bbcode = "see{url} now"

      expect_linked(bbcode, text: "see#{BARE_URL} now")
      expect(markdown(bbcode)).to eq("see[#{BARE_URL}](#{BARE_URL}) now")
    end

    it "links it when the BBCode has the URL only as text" do
      expect_linked("see[url]#{BARE_URL}[/url] now", text: "see#{BARE_URL} now")
    end

    it "links it with text after it" do
      expect_linked("see {url}now", text: "see #{BARE_URL}now")
    end

    it "links it with punctuation and text after it" do
      expect_linked("see {url}.now", text: "see #{BARE_URL}.now")
    end

    it "links it with a quote in front" do
      expect_linked(%(see "{url} now), text: %(see "#{BARE_URL} now))
    end
  end

  context "when the href has parentheses of its own" do
    it "keeps them in the link" do
      expect_linked("see {url} now", href: BARE_PAREN_URL, text: "see #{BARE_PAREN_URL} now")
      expect(markdown("see {url} now", href: BARE_PAREN_URL)).to eq("see #{BARE_PAREN_URL} now")
    end

    it "leaves a ) after it out of the link" do
      expect_linked("see ({url}) now", href: BARE_PAREN_URL, text: "see (#{BARE_PAREN_URL}) now")
    end
  end

  # linkify takes the delimiters of the formatting into the URL.
  { "[b]x[/b]" => "strong", "[i]x[/i]" => "em", "[s]x[/s]" => "s" }.each do |formatting, selector|
    it "links a URL with #{formatting} after it" do
      cooked = paragraph("see {url}#{formatting}")

      expect(links(cooked)).to eq([[BARE_URL, BARE_URL]]), cooked.to_html
      expect(cooked.at_css(selector).text).to eq("x")
    end
  end

  it "links a URL with formatting in front of it" do
    cooked = paragraph("[b]x[/b]{url} now")

    expect(links(cooked)).to eq([[BARE_URL, BARE_URL]]), cooked.to_html
    expect(cooked.at_css("strong").text).to eq("x")
  end
end
