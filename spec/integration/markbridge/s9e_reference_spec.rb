# frozen_string_literal: true

# Checks the TextFormatter parser against s9e\TextFormatter itself.
#
# The fixture has what s9e makes of the inputs of its own plugin tests:
# the XML it stores and the HTML it renders (see S9eReference and
# spec/support/s9e/generate.php). For every case this spec converts the
# XML with Markbridge, cooks the Markdown with the Discourse engine and
# compares the result with the HTML of s9e. A post that looks one way in
# phpBB or Flarum has to look the same way in Discourse.
#
# A case that differs is either an intended difference or a known bug,
# and both lists say why. The spec also checks that a listed case really
# differs, so a fix or a changed decision forces the list to be updated.
module S9eReference
  EMPTY_ELEMENT = "an element with nothing in it is not written, s9e writes the empty tags"
  LINK_WITHOUT_TEXT = "a link without text renders as the bare URL, so there is something to click"
  RELATIVE_ADDRESS =
    "Discourse drops the address of a link or an image that has no scheme and no leading " \
      "slash, and the renderer writes a link to a target that is no URL and no path as its text"
  CODE_SPAN_LINES = "a code span with a line break in it is written as a code block"
  EDGE_WHITESPACE =
    "whitespace at the edge of strikethrough is written outside of it, where Markdown needs it"
  COOKED_AUTOLINK =
    "Discourse links a www address or a mailto: in the text that s9e keeps as plain text"
  DECODED_LABEL =
    "a link whose text is its address renders as the bare URL, and Discourse shows it decoded"
  SPOILER_TITLE =
    "the title of a spoiler is a paragraph in front of it, Discourse has no place for it " \
      "in the spoiler"
  S9E_SELF_CLOSING = "s9e writes a self-closing BBCode back with other quotes than it stores"

  # Turn {reason => [keys]} into {key => reason}.
  def self.by_case(groups)
    groups
      .each_with_object({}) { |(reason, keys), map| keys.each { |key| map[key] = reason } }
      .freeze
  end

  # Cases where Markbridge deliberately renders something else, or where
  # Discourse does. A key is the profile and the input text.
  INTENDED_DIFFERENCES =
    by_case(
      EMPTY_ELEMENT => [
        "flarum: > *x* \n\n```\n```\n\n***",
        "flarum: ```\n```",
        "flarum: ``` ```",
        "flarum: ... ![1][b][/b] ...\n\n[1]: http://example.org/img.png",
        "flarum: [b][*]no <li> element without the right parent[/b]",
        "bbcodes: [b][*]no <li> element without the right parent[/b]",
        "bbcodes: x [b x][/b] y",
        "bbcodes: x [b foo x=1][/b] y",
      ],
      LINK_WITHOUT_TEXT => [
        "flarum: [](http://example.org/)",
        "flarum: [](http://example.org/?a=1&b=1)[](http://example.org/?a=1&amp;b=1)",
      ],
      RELATIVE_ADDRESS => [
        "flarum: ![alt\\\ntext](foo.png)",
        "flarum: ![alt](foo.png \"line1\nline2\")",
        "flarum: ![alt\ntext](img)",
        "flarum: [img height=123 width=potato]img.png[/img]",
        "flarum: [img height=potato width=456]img.png[/img]",
        "bbcodes: [img height=123 width=potato]img.png[/img]",
        "bbcodes: [img height=potato width=456]img.png[/img]",
        "flarum: [x](x \"\\a\\b\\\\\\c\\*\\`\")",
        "flarum: [x](x \"foo \\\"bar\\\"\")",
        "flarum: [x](x 'foo \\'bar\\'')",
        "flarum: [x](x (foo \\(bar\\)))",
        "flarum: [x](x \"a\nb\")",
        "flarum: > [x](x \"a\n> b\")",
        "bbcodes: [c][url][/c][url=http://example.org]...[/url]",
      ],
      CODE_SPAN_LINES => ["flarum: `foo\nbar`"],
      EDGE_WHITESPACE => ["flarum: .. ~~foo\\~~ ~~bar~~ ..", "flarum: our [del]great [/del]leader"],
      COOKED_AUTOLINK => [
        "flarum: WWW address: www.example.org",
        "flarum: WWW ADDRESS: WWW.EXAMPLE.ORG",
        "flarum: WWW address: www.example.org ...",
        "flarum: (mailto:user@localhost)",
        "bbcodes: WWW address: www.example.org",
        "bbcodes: WWW ADDRESS: WWW.EXAMPLE.ORG",
        "bbcodes: WWW address: www.example.org ...",
        "bbcodes: (mailto:user@localhost)",
      ],
      DECODED_LABEL => [
        "flarum: http://www.xn--lyp-plada.com for http://www.älypää.com",
        "flarum: http://en.wikipedia.org/wiki/Matti_Nyk%C3%A4nen for " \
          "http://en.wikipedia.org/wiki/Matti_Nykänen",
        "bbcodes: http://www.xn--lyp-plada.com for http://www.älypää.com",
        "bbcodes: http://en.wikipedia.org/wiki/Matti_Nyk%C3%A4nen for " \
          "http://en.wikipedia.org/wiki/Matti_Nykänen",
      ],
      SPOILER_TITLE => [
        "bbcodes: Spoiler ahead!\n[spoiler=\"your spoilage status\"]Now you're spoiled[/spoiler]",
        "bbcodes: Spoiler ahead!\n[spoiler][spoiler='Last chance']Now you're spoiled" \
          "[/spoiler][/spoiler]",
      ],
      S9E_SELF_CLOSING => ["bbcodes: x [b x='\"bar\"'/] y", "bbcodes: x [b x='\\''/] y"],
    )

  # Cases that differ because of a defect. Fixing one must remove its entry.
  KNOWN_BUGS = by_case({})

  # Truncated input for the description of an example.
  def self.preview(kase)
    text = kase.text.strip.tr("\n", "⏎")
    text = "#{text[0, 47]}..." if text.length > 50
    "#{text} (#{kase.profile}, #{kase.source})"
  end
end

RSpec.describe "s9e TextFormatter reference", :discourse_engine do
  # Converts one case and returns both sides in the common form, plus the
  # message that tells the whole story when they are not what the lists
  # say they should be.
  def compare(kase)
    renderer = DiscourseEngineCooker.renderer(:all)
    markdown = Markbridge.text_formatter_xml_to_markdown(kase.xml, renderer:).markdown
    cooked = DiscourseEngineCooker.cook(markdown, profile: :all)
    message =
      "#{kase.key.inspect}\n" \
        "XML:      #{kase.xml.inspect}\n" \
        "Markdown: #{markdown.inspect}\n" \
        "Cooked:   #{cooked.inspect}\n" \
        "s9e HTML: #{kase.html.inspect}"

    [S9eReference.normalize(cooked), S9eReference.normalize(kase.html), message]
  end

  it "has a handler for every element of the fixture" do
    unknown = S9eReference.cases.flat_map { |kase| S9eReference.unknown_elements(kase.xml) }.uniq

    expect(unknown).to be_empty
  end

  it "names every case by a key of its own" do
    keys = S9eReference.cases.map(&:key)

    expect(keys.uniq.size).to eq(keys.size)
  end

  it "lists no case as both an intended difference and a known bug" do
    overlap = S9eReference::INTENDED_DIFFERENCES.keys & S9eReference::KNOWN_BUGS.keys

    expect(overlap).to be_empty
  end

  it "lists only cases of the fixture" do
    listed = S9eReference::INTENDED_DIFFERENCES.keys + S9eReference::KNOWN_BUGS.keys

    expect(listed - S9eReference.cases.map(&:key)).to be_empty
  end

  S9eReference.cases.each do |kase|
    reason = S9eReference::INTENDED_DIFFERENCES[kase.key] || S9eReference::KNOWN_BUGS[kase.key]

    if reason
      it "differs from s9e for #{S9eReference.preview(kase)}: #{reason}" do
        ours, theirs, message = compare(kase)

        expect(ours).not_to eq(theirs),
        "this case matches s9e now, remove it from the list\n#{message}"
      end
    else
      it "matches s9e for #{S9eReference.preview(kase)}" do
        ours, theirs, message = compare(kase)

        expect(ours).to eq(theirs), message
      end
    end
  end
end
