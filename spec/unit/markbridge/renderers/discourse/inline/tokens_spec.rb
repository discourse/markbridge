# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Inline::Tokens do
  it "builds a text token that is escaped by default" do
    expect(described_class.text("a")).to eq([:text, "a", :escape])
  end

  it "builds a text token with the given mode" do
    expect(described_class.text("a", described_class::LABEL)).to eq([:text, "a", :label])
  end

  it "takes finished Markdown as it is" do
    markdown = "**a**"

    expect(described_class.raw(markdown)).to be(markdown)
  end

  it "shares one frozen token per delimiter for open and close" do
    expect(described_class.open(:strong)).to eq(%i[open strong])
    expect(described_class.open(:strong)).to be(described_class.open(:strong))
    expect(described_class.open(:strong)).to be_frozen
    expect(described_class.close(:strong)).to eq(%i[close strong])
    expect(described_class.close(:em)).to be(described_class.close(:em))
    expect(described_class.close(:em)).to be_frozen
  end

  it "builds the tokens with one value" do
    expect(described_class.code("x")).to eq([:code, "x"])
    expect(described_class.link_open("/a")).to eq([:link_open, "/a"])
    expect(described_class.bare_url("https://a")).to eq([:bare_url, "https://a"])
    expect(described_class.html("<sup>2</sup>")).to eq([:html, "<sup>2</sup>"])
  end

  it "builds an image token with every attribute in its place" do
    expect(described_class.image(src: "a.png", alt: "x", width: 1, height: 2)).to eq(
      [:image, "a.png", "x", 1, 2],
    )
  end

  it "builds an image token with the source alone" do
    expect(described_class.image(src: "a.png")).to eq([:image, "a.png", nil, nil, nil])
  end

  it "shares one frozen token for every link close and every hard break" do
    expect(described_class.link_close).to be(described_class.link_close)
    expect(described_class.link_close).to eq([:link_close])
    expect(described_class.link_close).to be_frozen
    expect(described_class.hard_break).to be(described_class.hard_break)
    expect(described_class.hard_break).to eq([:hard_break])
    expect(described_class.hard_break).to be_frozen
  end

  describe ".placeholder" do
    it "builds a placeholder token with the text and what will most likely replace it" do
      expect(described_class.placeholder("[link|1]", like: "https://e.com")).to eq(
        [:placeholder, "[link|1]", "https://e.com"],
      )
    end

    it "refuses a like: that is empty or no String" do
      expect { described_class.placeholder("[link|1]", like: "") }.to raise_error(
        ArgumentError,
        'like: must be a non-empty String, got ""',
      )
      expect { described_class.placeholder("[link|1]", like: nil) }.to raise_error(
        ArgumentError,
        "like: must be a non-empty String, got nil",
      )
      expect { described_class.placeholder("[mention|1]", like: :alice) }.to raise_error(
        ArgumentError,
        "like: must be a non-empty String, got :alice",
      )
    end
  end

  describe ".visible?" do
    it "is true for a placeholder whose like: is visible, whatever the placeholder" do
      expect(described_class.visible?([described_class.placeholder(" ", like: "@a")])).to be(true)
      expect(described_class.visible?([described_class.placeholder("[x|1]", like: " ")])).to be(
        false,
      )
    end

    it "is true for text, Markdown or HTML with something other than whitespace" do
      expect(described_class.visible?([described_class.text(" a")])).to be(true)
      expect(described_class.visible?([described_class.raw("*")])).to be(true)
      expect(described_class.visible?(["", described_class.text("a")])).to be(true)
      expect(described_class.visible?([described_class.html("<sup>2</sup>")])).to be(true)
    end

    it "is true for code with content, a link, a bare URL and an image" do
      expect(described_class.visible?([described_class.code("x")])).to be(true)
      expect(described_class.visible?([described_class.link_open("/a")])).to be(true)
      expect(described_class.visible?([described_class.bare_url("https://a")])).to be(true)
      expect(described_class.visible?([described_class.image(src: "a.png")])).to be(true)
    end

    it "is false for whitespace, empty code, delimiters and hard breaks" do
      tokens = [
        described_class.text(" \n"),
        described_class.raw(""),
        described_class.code(""),
        described_class.open(:em),
        described_class.close(:em),
        described_class.hard_break,
        described_class.link_close,
      ]

      expect(described_class.visible?(tokens)).to be(false)
      expect(described_class.visible?([])).to be(false)
    end
  end

  it "names the delimiters the serializer knows" do
    expect(described_class::DELIMITERS).to eq(%i[strong em s u])
    expect(described_class::DELIMITERS).to match_array(
      Markbridge::Renderers::Discourse::Inline::Serializer::DELIMITERS.keys,
    )
  end
end
