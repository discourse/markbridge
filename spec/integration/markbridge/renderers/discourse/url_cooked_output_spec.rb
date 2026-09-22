# frozen_string_literal: true

require "nokogiri"

RSpec.describe "link cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  # @return [Nokogiri::XML::Element, nil] the first anchor in the cooked HTML
  def anchor(html)
    Nokogiri::HTML.fragment(html).at_css("a")
  end

  it "cooks a bare URL glued to text into a link" do
    link = anchor(cook("see[url=https://example.com/t/5]https://example.com/t/5[/url]"))

    expect(link["href"]).to eq("https://example.com/t/5")
    expect(link.text).to eq("https://example.com/t/5")
  end

  it "cooks a glued bare URL with Markdown characters into a link with the URL as text" do
    # The BBCode option syntax cannot carry a `]`, the HTML parser can.
    html =
      cook_html(%(<p>see<a href="https://example.com/a]b_c">https://example.com/a]b_c</a>now</p>))
    link = anchor(html)

    expect(link["href"]).to eq("https://example.com/a%5Db_c")
    expect(link.text).to eq("https://example.com/a]b_c")
    expect(Nokogiri::HTML.fragment(html).at_css("p").text).to eq("seehttps://example.com/a]b_cnow")
  end

  it "cooks a glued link without text into a link with the URL as text" do
    link = anchor(cook_html(%(<p>see<a href="https://example.com/a_b"></a>now</p>)))

    expect(link["href"]).to eq("https://example.com/a_b")
    expect(link.text).to eq("https://example.com/a_b")
  end
end
