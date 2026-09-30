# frozen_string_literal: true

require "nokogiri"

RSpec.describe "image cooked output", skip: CookedOutput::SKIP_REASON do
  def round_trip_src(src)
    markdown = Markbridge.html_to_markdown(%(<img src="#{src}" alt="x">)).markdown
    cooked = Commonmarker.to_html(markdown, options: CookedOutput::OPTIONS)

    Nokogiri::HTML5.fragment(cooked).at_css("img")&.[]("src")
  end

  it "preserves image sources with unbalanced parentheses" do
    expect(round_trip_src("a(b.png")).to eq("a(b.png")
    expect(round_trip_src("a)b.png")).to eq("a)b.png")
  end
end
