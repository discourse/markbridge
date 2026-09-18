# frozen_string_literal: true

require "nokogiri"

RSpec.describe "aligned block cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  it "cooks a link inside an aligned block into an anchor" do
    html = cook("[center][url=https://example.com]a link[/url][/center]")

    expect(html).to include(%(<a href="https://example.com">a link</a>))
  end

  it "cooks emphasis inside an aligned block" do
    expect(cook("[center][b]bold[/b][/center]")).to include("<strong>bold</strong>")
  end

  it "cooks a list inside an aligned block into a real list" do
    html = cook("[center][list][*]a[*]b[/list][/center]")

    expect(html).to include("<ul>").and include("<li>a</li>")
  end

  context "when the aligned block is nested in a list item" do
    it "cooks a link into an anchor" do
      html = cook("[list][*]parent[center][url=https://example.com]a link[/url][/center][/list]")

      expect(html).to include(%(<a href="https://example.com">a link</a>))
    end

    it "cooks a nested list into a real list" do
      html = cook("[list][*]parent[center][list][*]a[*]b[/list][/center][/list]")

      expect(html).to include("<ul>").and include("<li>a</li>")
      expect(html).not_to include("- a")
    end

    it "cooks a nested list the same way when the source has its own blank lines" do
      html = cook("[list][*]parent[center]\n\n[list][*]a[*]b[/list][/center][/list]")

      expect(html).to include("<ul>").and include("<li>a</li>")
      expect(html).not_to include("- a")
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
      expect(item_depths(Nokogiri::HTML5.fragment(html))).to eq(
        "outer" => 0,
        "parent" => 1,
        "a" => 2,
        "b" => 2,
        "c" => 2,
      )
    end
  end
end
