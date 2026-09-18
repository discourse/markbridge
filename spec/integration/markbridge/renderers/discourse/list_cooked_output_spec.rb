# frozen_string_literal: true

require "nokogiri"

# Nested list indentation is only correct if CommonMark puts every
# block back where it belongs. The Markdown string alone does not show
# that: an item indented two columns too far turns its code fence into
# an indented code block, and the fence characters become text.
RSpec.describe "list cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  def fragment(bbcode)
    Nokogiri::HTML5.fragment(cook(bbcode))
  end

  it "cooks a code block three levels deep into a pre with the code as its text" do
    pre =
      fragment("[list][*]a[list][*]b[list][*]c[code]x\ny[/code][/list][/list][/list]").css("pre")

    expect(pre.size).to eq(1)
    expect(pre.text).to eq("x\ny\n")
  end

  it "cooks a code block into a pre when ordered and unordered lists alternate" do
    doc = fragment("[list=1][*]a[list][*]b[list=1][*]c[code]x\ny[/code][/list][/list][/list]")

    expect(doc.css("pre").text).to eq("x\ny\n")
    expect(doc.css("ol li ul li ol li pre").size).to eq(1)
  end

  it "keeps a code block inside its own item and the text after it in the outer item" do
    doc = fragment("[list][*]outer[list][*][code]  x[/code][/list]after[/list]")

    expect(doc.css("ul li ul li pre").text).to eq("  x\n")
    expect(doc.css("ul > li").first.xpath("text()").map(&:text).join).to include("after")
  end

  it "keeps a code block inside an ordered item that also has a paragraph" do
    doc = fragment("[list=1][*]parent[code]def f\n  return 1\nend[/code][/list]")

    expect(doc.css("ol > li > p").text).to eq("parent")
    expect(doc.css("ol > li > pre").text).to eq("def f\n  return 1\nend\n")
  end

  it "cooks a nested list after an HTML table inside a list item into a real list" do
    doc =
      fragment(
        "[list][*]item[table][tr][td]a[/td][/tr][tr][td]b[/td][td]c[/td][/tr][/table]" \
          "[list][*]x[/list][/list]",
      )

    expect(doc.css("ul > li > table").size).to eq(1)
    expect(doc.css("ul > li > ul > li").map(&:text)).to eq(["x"])
  end

  context "when a list item starts with < but opens no HTML block" do
    it "leaves a list under an autolink tight" do
      html = cook("[list][*]<https://example.com>\n[list][*]child[/list][*]sibling[/list]")

      expect(html).to include("<li>child</li>").and include("<li>sibling</li>")
      expect(html).not_to include("<p>")
    end

    it "leaves a list under inline HTML tight" do
      html = cook("[list][*][color=red]red[/color]\n[list][*]child[/list][*]sibling[/list]")

      expect(html).to include("<li>child</li>").and include("<li>sibling</li>")
      expect(html).not_to include("<p>")
    end
  end
end
