# frozen_string_literal: true

require "json"
require "nokogiri"

# The reference cases of s9e\TextFormatter: for an input text, the XML
# s9e stores and the HTML s9e renders from it. `spec/support/s9e/generate.php`
# writes them by running s9e over the inputs of its own plugin tests, with
# two forum profiles: "flarum" (what Flarum turns on) and "bbcodes" (the
# BBCodes of the s9e repository that Markbridge reads).
#
# s9e_reference_spec.rb converts the XML with Markbridge, cooks the
# Markdown with the Discourse engine and compares the result with the HTML
# of s9e. The two sides are HTML from two different engines, so +normalize+
# brings both into one form first. Every rule there is a difference
# between the two engines that says nothing about Markbridge, like the
# anchor Discourse puts into a heading.
module S9eReference
  FIXTURE = File.expand_path("../fixtures/s9e/cases.json", __dir__)

  Case =
    Data.define(:profile, :source, :text, :xml, :html) do
      # @return [String] what the lists of the spec name a case by
      def key
        "#{profile}: #{text}"
      end
    end

  # Elements of the XML that are no content: the roots, the markup of the
  # source, the line break and the paragraph of Litedown.
  STRUCTURE = %w[r t s e i br p].freeze

  TAG_NAMES = { "b" => "strong", "i" => "em", "del" => "s", "strike" => "s" }.freeze
  BBCODE_CLASSES = {
    "bbcode-b" => "strong",
    "bbcode-i" => "em",
    "bbcode-u" => "u",
    "bbcode-s" => "s",
  }.freeze
  HEADING_ANCHORS = "h1 > a, h2 > a, h3 > a, h4 > a, h5 > a, h6 > a"
  BLOCKS = %w[ul ol li blockquote pre h1 h2 h3 h4 h5 h6 hr table tr th td align spoiler].freeze
  # What the typographer of Discourse writes, and what it was.
  TYPOGRAPHY = { "…" => "...", "→" => "->", "←" => "<-", "↔" => "<->" }.freeze
  CURLY_QUOTES = "“”‘’"
  STRAIGHT_QUOTES = "\"\"''"
  BREAK_RUN = /(?:<br>)+/
  BLOCK_TAG = "</?(?:#{BLOCKS.join("|")})(?: [^>]*)?>"

  module_function

  # @return [Array<Case>]
  def cases
    @cases ||= JSON.parse(File.read(FIXTURE)).fetch("cases").map { |entry| Case.new(**entry) }
  end

  # @return [String] the s9e commit the fixture was made with
  def revision
    JSON.parse(File.read(FIXTURE)).fetch("s9e")
  end

  # The elements of the XML that the parser has no handler for.
  # @return [Array<String>]
  def unknown_elements(xml)
    registry = Markbridge::Parsers::TextFormatter::HandlerRegistry.shared_default
    names = Nokogiri.XML(xml).xpath("//*").map(&:name).uniq - STRUCTURE
    names.reject { |name| registry.has_handler?(name) || registry.transparent_tags.include?(name) }
  end

  # @param html [String] HTML of s9e or of the Discourse engine
  # @return [String] the same content in the form both engines share
  def normalize(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.xpath(".//comment()").each(&:remove)
    # s9e puts a highlighter script into a code block.
    fragment.css("script").each(&:remove)
    # Discourse puts an anchor into a heading.
    fragment.css(HEADING_ANCHORS).each { |anchor| anchor.remove if anchor.text.empty? }

    remove_labels(fragment)

    fragment.css("*").each { |element| rename(element) }
    unwrap_presentation(fragment)
    order_emphasis(fragment)
    fragment.traverse { |node| normalize_text(node) if node.text? }

    trim_breaks(fragment.to_html)
  end

  # What an engine writes in front of a quote or a spoiler on its own:
  # "alice wrote:" in s9e and "alice:" in Discourse for a quote with an
  # author, "Spoiler:" in s9e for a spoiler without a title.
  def remove_labels(fragment)
    fragment.css("blockquote cite, aside.quote > .title").each(&:remove)
    fragment.css("aside.quote").each { |aside| aside.replace(aside.children) }
    fragment
      .css("details.spoiler > summary")
      .each { |summary| summary.remove if summary.text.strip == "Spoiler:" }
  end

  # One name per meaning and only the attributes that carry content. The
  # two engines write a spoiler, underline, alignment and a code language
  # each in their own way.
  def rename(element)
    classes = element["class"].to_s.split
    name = canonical_name(element, classes)
    kept = kept_attributes(element, classes)

    element.attribute_nodes.each(&:remove)
    kept.each { |attribute, value| element[attribute] = value }
    element.name = name
  end

  def canonical_name(element, classes)
    # A line with one inline spoiler is a block spoiler to Discourse, so
    # the two kinds are one here.
    return "spoiler" if classes.include?("spoiler")
    if element.name == "div" && (element["align"] || element["style"].to_s.include?("text-align"))
      return "align"
    end

    bbcode = classes.filter_map { |name| BBCODE_CLASSES[name] }.first
    bbcode || TAG_NAMES.fetch(element.name, element.name)
  end

  def kept_attributes(element, classes)
    case element.name
    when "a"
      { "href" => element["href"].to_s }
    when "img"
      alt = element["alt"].to_s.gsub(/\s+/, " ")
      alt.empty? ? { "src" => element["src"].to_s } : { "src" => element["src"].to_s, "alt" => alt }
    when "code"
      language = classes.filter_map { |name| name[/\Alang(?:uage)?-(.+)\z/, 1] }.first
      language && language != "auto" ? { "lang" => language } : {}
    else
      {}
    end
  end

  # Elements that only carry a style or group other elements. A paragraph
  # is one of them: s9e has paragraphs only with Litedown, without it a
  # blank line is two line breaks, so a paragraph becomes its content
  # between two breaks.
  def unwrap_presentation(fragment)
    fragment.css("li > p").each { |paragraph| paragraph.replace(paragraph.children) }
    fragment
      .css("p")
      .each do |paragraph|
        paragraph.add_previous_sibling("<br>")
        paragraph.add_next_sibling("<br>")
        paragraph.replace(paragraph.children)
      end
    fragment.css("span, div, thead, tbody, cite").each { |node| node.replace(node.children) }
  end

  # `***x***` is strong in em for markdown-it and em in strong for s9e.
  def order_emphasis(fragment)
    fragment
      .css("em > strong")
      .each do |strong|
        em = strong.parent
        next unless em.children.size == 1

        em.name = "strong"
        strong.name = "em"
      end
  end

  def normalize_text(node)
    if node.ancestors.any? { |ancestor| ancestor.name == "pre" }
      # A line break in code has to stay visible in the result.
      node.content = node.text.sub(/\n\z/, "").gsub("\n", "⏎")
      return
    end

    text = node.text.gsub(/\s+/, " ").tr(CURLY_QUOTES, STRAIGHT_QUOTES)
    TYPOGRAPHY.each { |written, source| text = text.gsub(written, source) }
    text.empty? ? node.remove : node.content = text
  end

  # A run of line breaks is one, and a break or a space at the edge of a
  # block or of the whole text is layout.
  def trim_breaks(html)
    html = html.gsub(/\s*<br>\s*/, "<br>").gsub(BREAK_RUN, "<br>")
    html = html.gsub(/(?:<br>|\s)+(?=#{BLOCK_TAG})/, "").gsub(/(#{BLOCK_TAG})(?:<br>|\s)+/, "\\1")
    html.gsub(/\A(?:<br>|\s)+|(?:<br>|\s)+\z/, "")
  end
end
