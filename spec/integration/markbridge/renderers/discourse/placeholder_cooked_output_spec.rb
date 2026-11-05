# frozen_string_literal: true

# A placeholder token is written as it is, and a later step replaces it
# with its like: value. These checks do that replacement and cook the
# result, which is what the forum shows in the end.
RSpec.describe "placeholder cooked output", skip: CookedOutput::SKIP_REASON do
  include CookedOutput

  let(:tokens) { Markbridge::Renderers::Discourse::Inline::Tokens }
  let(:url) { "https://forum.example.com/t/17" }

  # Renders every link as a placeholder, then replaces the placeholders
  # with the URL, like an importer does.
  def cook_replaced(bbcode)
    placeholder = tokens.placeholder("[link|17]", like: url)
    tag = Markbridge::Renderers::Discourse::Tag.new { |_element, _interface| [placeholder] }
    renderer = Markbridge.discourse_renderer(tags: { Markbridge::AST::Url => tag })
    markdown = Markbridge.bbcode_to_markdown(bbcode, renderer:).markdown

    cook_markdown(markdown.gsub("[link|17]", url))
  end

  it "cooks bold that ends with punctuation right before the replaced link" do
    html = cook_replaced("[b]See:[/b][url]http://old.example.com/?t=17[/url]")

    expect(fragment(html).at_css("strong").text).to eq("See:")
    expect(fragment(html).at_css("a")["href"]).to eq(url)
  end

  it "cooks italic that starts with punctuation right after the replaced link" do
    html = cook_replaced("[url]http://old.example.com/?t=17[/url][i].txt[/i]")

    expect(fragment(html).at_css("em").text).to eq(".txt")
  end
end
