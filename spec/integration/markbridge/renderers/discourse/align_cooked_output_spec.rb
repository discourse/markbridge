# frozen_string_literal: true

RSpec.describe "aligned block cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  it "cooks a link inside an aligned block into an anchor" do
    div = fragment(cook("[center][url=https://example.com]a link[/url][/center]")).at_css("div")

    expect(div["align"]).to eq("center")
    expect(div.at_css("a")["href"]).to eq("https://example.com")
    expect(div.at_css("a").text).to eq("a link")
  end

  it "cooks emphasis inside an aligned block" do
    div = fragment(cook("[center][b]bold[/b][/center]")).at_css("div")

    expect(div.at_css("strong").text).to eq("bold")
  end

  it "cooks a list inside an aligned block into a real list" do
    div = fragment(cook("[center][list][*]a[*]b[/list][/center]")).at_css("div")

    expect(div.css("ul > li").map(&:text)).to eq(%w[a b])
  end

  context "when the aligned block is nested in a list item" do
    it "cooks a link into an anchor" do
      html =
        fragment(
          cook("[list][*]parent[center][url=https://example.com]a link[/url][/center][/list]"),
        )

      expect(html.at_css("li > div a")["href"]).to eq("https://example.com")
    end

    it "cooks a nested list into a real list" do
      html = fragment(cook("[list][*]parent[center][list][*]a[*]b[/list][/center][/list]"))

      expect(html.css("li > div > ul > li").map(&:text)).to eq(%w[a b])
    end

    it "cooks a nested list the same way when the source has its own blank lines" do
      html = fragment(cook("[list][*]parent[center]\n\n[list][*]a[*]b[/list][/center][/list]"))

      expect(html.css("li > div > ul > li").map(&:text)).to eq(%w[a b])
    end
  end

  # Crossed tags do not show up in the Markdown; only an HTML5 parser
  # resolving the mis-nesting reveals the hoisted sibling list.
  context "when the aligned block is nested two list levels deep" do
    let(:html) do
      cook(
        "[list][*]outer[list][*]parent[center][list][*]a[*]b[/list][/center]" \
          "[list][*]c[/list][/list][/list]",
      )
    end

    def item_depths(fragment)
      fragment
        .css("li")
        .to_h do |li|
          label = li.xpath("text()|*/text()").map(&:text).map(&:strip).reject(&:empty?).first
          [label, li.ancestors("li").size]
        end
    end

    it "closes the div around the inner list instead of inside its last item" do
      expect(html).to include("<div align=\"center\">\n<ul>")
      expect(html).not_to include("</p>\n</div>")
    end

    it "keeps every item at its own level once the HTML is parsed" do
      expect(item_depths(fragment(html))).to eq(
        "outer" => 0,
        "parent" => 1,
        "a" => 2,
        "b" => 2,
        "c" => 2,
      )
    end
  end
end
