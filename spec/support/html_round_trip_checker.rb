# frozen_string_literal: true

require_relative "round_trip_checker"
require_relative "ast_html_writer"

# The round trip that starts with HTML: a tree is written as HTML
# (AstHtmlWriter), the HTML is converted to Markdown, the Markdown is
# cooked, and the cooked HTML is compared with the HTML the conversion
# started from. Both are read the same way, with the methods of
# RoundTripChecker for cooked HTML:
#
# - structure: the same skeleton of lists, quotes, code, links,
#   emphasis, headings and tables
# - text: the same visible text, with a separator around every block,
#   so two paragraphs that became one line are seen
# - links: the same link and image destinations
#
# The tree is only where the HTML comes from. It is written in every
# style of AstHtmlWriter, and the first style that fails is reported:
# a `<div>` for a paragraph is another input for the parser than a `<p>`.
#
# What the two sides may differ in without a failure: `<b>` is `<strong>`,
# `<div>` is `<p>`, a header cell is a cell (a Markdown table always has
# a header row).
class HtmlRoundTripChecker < RoundTripChecker
  SAME_TAGS = {
    "b" => "strong",
    "i" => "em",
    "strike" => "s",
    "div" => "p",
    "section" => "p",
    "th" => "td",
  }.freeze

  # @param document [Markbridge::AST::Document] a tree that
  #   AstHtmlWriter.lower has reduced to what HTML can say
  # @return [Array<Failure>] of the first style that fails, empty when
  #   every style round-trips
  def failures(document)
    AstHtmlWriter::STYLES.each do |name, style|
      found = style_failures(AstHtmlWriter.new(style).write(document))
      next if found.empty?

      return(
        found.map do |failure|
          Failure.new(check: failure.check, message: "style #{name}: #{failure.message}")
        end
      )
    end
    []
  end

  # The HTML of the first style that fails, its Markdown, the cooked
  # HTML and the failures.
  #
  # @param document [Markbridge::AST::Document]
  # @param label [String]
  # @return [String]
  def report(document, label:)
    style =
      AstHtmlWriter::STYLES.values.find do |candidate|
        !style_failures(AstHtmlWriter.new(candidate).write(document)).empty?
      end
    html = AstHtmlWriter.new(style || AstHtmlWriter::STYLES.fetch(:plain)).write(document)
    markdown = convert(html)
    parts = [label, "", "HTML:", html, "", "Markdown:", markdown, "", "Cooked:", cook(markdown)]
    failures(document).each { |failure| parts << "" << "#{failure.check}: #{failure.message}" }
    parts.join("\n")
  end

  private

  def style_failures(html)
    source = simplified(Nokogiri::HTML5.fragment(html))
    cooked = simplified(Nokogiri::HTML5.fragment(cook(convert(html))))

    [
      compare(:structure, skeleton_of(source), skeleton_of(cooked)),
      compare(:text, text_of(source), text_of(cooked)),
      compare(:links, links_of(source), links_of(cooked)),
    ].compact
  end

  def convert(html)
    Markbridge.html_to_markdown(html, renderer: @renderer).markdown
  end

  def simplified(fragment)
    fragment.css(SAME_TAGS.keys.join(", ")).each { |node| node.name = SAME_TAGS.fetch(node.name) }
    fragment
  end

  def skeleton_of(fragment)
    format_skeleton(actual_skeleton(fragment.children))
  end

  def text_of(fragment)
    normalize_text(cooked_text(fragment, +""))
  end

  def links_of(fragment)
    fragment.css("a[href], img[src]").map { |node| decode(node["href"] || node["src"]) }.sort
  end

  def compare(check, source, cooked)
    return if source == cooked

    Failure.new(
      check:,
      message: "the HTML has\n#{indent(source)}\nbut the cooked Markdown has\n#{indent(cooked)}",
    )
  end

  def indent(value)
    (value.is_a?(String) ? value : value.inspect).gsub(/^/, "  ")
  end
end
