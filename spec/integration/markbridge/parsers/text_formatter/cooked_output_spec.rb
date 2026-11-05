# frozen_string_literal: true

require "nokogiri"

RSpec.describe "TextFormatter cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  it "cooks a line break into <br> inside one paragraph" do
    expect(cook_text_formatter("<t>a<br/>\nb</t>")).to eq("<p>a<br>\nb</p>\n")
  end

  it "cooks two line breaks into two paragraphs" do
    expect(cook_text_formatter("<t>a<br/>\n<br/>\nb</t>")).to eq("<p>a</p>\n<p>b</p>\n")
  end

  it "cooks a line break at the start of link text in front of the link" do
    html =
      cook_text_formatter(
        %(<r>see<br/>\n<URL url="https://e.com/a"><s>[url]</s><br/>\nlabel<e>[/url]</e></URL> ok</r>),
      )

    expect(html).to eq(%(<p>see<br>\n<br><a href="https://e.com/a">label</a> ok</p>\n))
  end

  it "cooks a link whose text is the href after a line break into the link" do
    html =
      cook_text_formatter(
        %(<r>see<br/>\n<URL url="https://e.com/a"><s>[url]</s><br/>\nhttps://e.com/a<e>[/url]</e></URL> ok</r>),
      )

    expect(html).to eq(%(<p>see<br>\n<br><a href="https://e.com/a">https://e.com/a</a> ok</p>\n))
  end

  it "cooks bold across a line break" do
    html = cook_text_formatter("<r><B><s>[b]</s>a<br/>\nb<e>[/b]</e></B></r>")

    expect(html).to eq("<p><strong>a<br>\nb</strong></p>\n")
  end

  it "cooks the lines of a quote into one paragraph" do
    html =
      cook_text_formatter(
        "<r><QUOTE><s>[quote]</s>a <B><s>[b]</s>b<e>[/b]</e></B> c<br/>\nd<e>[/quote]</e></QUOTE></r>",
      )

    expect(html).to eq("<blockquote>\n<p>a <strong>b</strong> c<br>\nd</p>\n</blockquote>\n")
  end

  it "cooks lines that look like Markdown into plain text" do
    html = cook_text_formatter("<t>1. first<br/>\n* star<br/>\n___<br/>\n~~~~</t>")
    dom = Nokogiri::HTML5.fragment(html)

    expect(dom.element_children.map(&:name)).to eq(["p"])
    expect(dom.text).to eq("1. first\n* star\n___\n~~~~\n")
  end

  it "cooks indented text into a paragraph, not a code block" do
    expect(cook_text_formatter("<t>a<br/>\n          b</t>")).to eq("<p>a<br>\nb</p>\n")
  end

  it "cooks indented text in an inline element into a paragraph" do
    html = cook_text_formatter("<r>a<br/>\n<B><s>[b]</s>          b<e>[/b]</e></B></r>")

    expect(html).to eq("<p>a<br>\n<strong>b</strong></p>\n")
  end

  it "cooks indented text at the start of the post into a paragraph" do
    expect(cook_text_formatter("<t>          a</t>")).to eq("<p>a</p>\n")
  end

  it "cooks bold that starts with underline after a letter into bold" do
    html = cook_text_formatter("<r>a<B><U>b</U> c</B>d</r>")

    expect(html).to include("<strong>[u]b[/u] c</strong>")
  end

  it "cooks code with its indentation" do
    html = cook_text_formatter("<r><CODE><s>[code]</s>line1\n    line2<e>[/code]</e></CODE></r>")

    dom = Nokogiri::HTML5.fragment(html)

    expect(dom.element_children.map(&:name)).to eq(["pre"])
    expect(dom.text).to eq("line1\n    line2\n\n")
  end
end
