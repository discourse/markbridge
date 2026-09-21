# frozen_string_literal: true

require "spec_helper"

RSpec.describe "HTML inline whitespace", skip: CookedOutput::SKIP_REASON do
  def converted_dom(html)
    markdown = Markbridge.html_to_markdown(html).markdown
    Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: CookedOutput::OPTIONS))
  end

  it "renders a punctuation-ending label identically with whitespace inside or outside strong" do
    inside = converted_dom("<p><strong>Tyler: </strong>text</p>")
    outside = converted_dom("<p><strong>Tyler:</strong> text</p>")

    expect(inside.to_html).to eq(outside.to_html)
    expect(inside.at_css("strong").text).to eq("Tyler:")
    expect(inside.at_css("p").text).to eq("Tyler: text")
  end

  it "collapses a space inside and a space outside an inline element into one" do
    dom = converted_dom("<p><strong>Tyler: </strong> text</p>")

    expect(dom.at_css("p").text).to eq("Tyler: text")
    expect(dom.at_css("strong").text).to eq("Tyler:")
  end

  it "drops the space at the end of a block even when an inline element holds it" do
    dom = converted_dom("<p>first</p><p><strong>label </strong></p><p>next</p>")

    expect(dom.css("p").map(&:text)).to eq(%w[first label next])
  end

  it "keeps the separator before an inline label" do
    dom = converted_dom("<p>before<strong> label</strong></p>")

    expect(dom.at_css("p").text).to eq("before label")
    expect(dom.at_css("strong").text).to eq("label")
  end

  it "preserves spaces across nested and transparent inline containers" do
    [
      "<strong><span>Tyler: </span></strong>",
      "<span style='font-weight:bold'>Tyler: </span>",
      "<b>Tyler: </b>",
    ].each do |label|
      dom = converted_dom("<p>#{label}text</p>")
      expect(dom.at_css("p").text).to eq("Tyler: text")
      expect(dom.at_css("strong").text).to eq("Tyler:")
    end
  end

  it "keeps separation between adjacent formatting elements" do
    dom = converted_dom("<p><strong>A </strong><em>B</em></p>")

    expect(dom.at_css("p").text).to eq("A B")
    expect(dom.at_css("strong").text).to eq("A")
    expect(dom.at_css("em").text).to eq("B")
  end

  it "keeps collapsed spaces inside links and nonbreaking spaces intact" do
    dom =
      converted_dom("<p>before<a href='/x'> link </a>after<strong> label:&nbsp;</strong>text</p>")

    expect(dom.at_css("p").text).to eq("before link after label:\u00a0text")
    expect(dom.at_css("a")["href"]).to eq("/x")
  end

  it "does not invent a separator for intentionally adjacent words" do
    dom = converted_dom("<p>pre<strong>fix</strong>suffix</p>")

    expect(dom.at_css("p").text).to eq("prefixsuffix")
  end

  it "does not turn block-edge indentation into code" do
    dom = converted_dom("<p>  <strong> label </strong>  </p><p> next </p>")

    expect(dom.css("pre,code")).to be_empty
    expect(dom.css("p").map(&:text)).to eq(%w[label next])
  end

  it "keeps literal code whitespace" do
    dom = converted_dom("<pre>  literal  \nnext  </pre>")

    expect(dom.at_css("code").text).to eq("  literal  \nnext  \n")
  end
end
