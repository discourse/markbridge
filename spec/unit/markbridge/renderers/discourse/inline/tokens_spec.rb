# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Inline::Tokens do
  it "builds a text token that is escaped by default" do
    expect(described_class.text("a")).to eq([:text, "a", :escape])
  end

  it "builds a text token with the given mode" do
    expect(described_class.text("a", described_class::LABEL)).to eq([:text, "a", :label])
  end

  it "builds the tokens with one value" do
    expect(described_class.raw("**a**")).to eq([:raw, "**a**"])
    expect(described_class.open(:strong)).to eq(%i[open strong])
    expect(described_class.close(:strong)).to eq(%i[close strong])
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

  it "names the delimiters the serializer knows" do
    expect(described_class::DELIMITERS).to eq(%i[strong em s u])
    expect(described_class::DELIMITERS).to match_array(
      Markbridge::Renderers::Discourse::Inline::Serializer::DELIMITERS.keys,
    )
  end
end
