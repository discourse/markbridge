# frozen_string_literal: true

RSpec.describe "image cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  def round_trip_src(src)
    fragment(cook_html(%(<img src="#{src}" alt="x">))).at_css("img")&.[]("src")
  end

  it "preserves image sources with unbalanced parentheses" do
    expect(round_trip_src("a(b.png")).to eq("a(b.png")
    expect(round_trip_src("a)b.png")).to eq("a)b.png")
  end
end
