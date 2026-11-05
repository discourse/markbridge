# frozen_string_literal: true

require "nokogiri"

RSpec.describe "emphasis across a blank line cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  it "cooks bold over two paragraphs into bold in each paragraph" do
    expect(cook("[b]a\n\nb[/b] c")).to eq(
      "<p><strong>a</strong></p>\n<p><strong>b</strong> c</p>\n",
    )
  end

  it "cooks italic over two paragraphs into italic in each paragraph" do
    expect(cook("[i]a\n\nb[/i]")).to eq("<p><em>a</em></p>\n<p><em>b</em></p>\n")
  end

  it "cooks strikethrough over two paragraphs into strikethrough in each paragraph" do
    expect(cook("[s]a\n\nb[/s]")).to eq("<p><s>a</s></p>\n<p><s>b</s></p>\n")
  end

  it "cooks nested formatting over two paragraphs" do
    html = cook_text_formatter("<r><B><I>a<br/><br/>b</I></B></r>")

    expect(html).to eq("<p><em><strong>a</strong></em></p>\n<p><em><strong>b</strong></em></p>\n")
  end

  it "cooks italic that a blank line splits inside bold" do
    html = cook("[b]a[i]b\n\nc[/i]d[/b]")

    expect(html).to eq("<p><strong>a<em>b</em></strong></p>\n<p><strong><em>c</em>d</strong></p>\n")
  end

  it "cooks bold over two paragraphs in a list item" do
    html = cook_text_formatter("<r><LIST><LI><B>a<br/>\n<br/>\nb</B></LI></LIST></r>")

    expect(html).to eq(
      "<ul>\n<li>\n<p><strong>a</strong></p>\n<p><strong>b</strong></p>\n</li>\n</ul>\n",
    )
  end

  it "cooks bold over two paragraphs in a quote" do
    html = cook_text_formatter("<r><QUOTE><B>a<br/>\n<br/>\nb</B></QUOTE></r>")

    expect(html).to eq(
      "<blockquote>\n<p><strong>a</strong></p>\n<p><strong>b</strong></p>\n</blockquote>\n",
    )
  end
end
