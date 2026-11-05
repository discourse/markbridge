# frozen_string_literal: true

# commonmarker doesn't know Discourse's [quote] BBCode, so these checks
# only cover the Markdown blockquotes.
RSpec.describe "quote cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  it "cooks a quote without author around a list into one blockquote with the list" do
    expect(cook("[quote][list][*]a[*]b[/list][/quote]")).to eq(
      "<blockquote>\n<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n</blockquote>\n",
    )
  end

  it "cooks a quote without author around a quote with author into no blockquote" do
    expect(cook("[quote][quote=X]in[/quote][/quote]reply")).not_to include("<blockquote>")
  end

  it "cooks the text around an empty quote into two paragraphs" do
    expect(cook("x[quote][/quote]y")).to eq("<p>x</p>\n<p>y</p>\n")
  end

  it "cooks nested quotes without author into nested blockquotes" do
    expect(cook("[quote][quote]in[/quote]out[/quote]")).to eq(
      "<blockquote>\n<blockquote>\n<p>in</p>\n</blockquote>\n<p>out</p>\n</blockquote>\n",
    )
  end
end
