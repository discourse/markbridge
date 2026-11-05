# frozen_string_literal: true

require "nokogiri"
require_relative "markdown_it_cooker"

# Helpers for specs that check the HTML markdown-it cooks from our
# Markdown. Asserting on the Markdown alone lets a collapsed blank line
# pass unnoticed: the string still looks plausible while the content
# cooks to literal text.
#
# Include it in an example group and guard the group with
# +CookedOutput::SKIP_REASON+:
#
#     RSpec.describe "…", skip: CookedOutput::SKIP_REASON do
#       include CookedOutput
#     end
module CookedOutput
  SKIP_REASON = MarkdownItCooker::SKIP_REASON

  # @param bbcode [String]
  # @return [String] the HTML that markdown-it cooks from our Markdown
  def cook(bbcode)
    cook_markdown(Markbridge.bbcode_to_markdown(bbcode).markdown)
  end

  # @param html [String]
  # @return [String] the HTML that markdown-it cooks from our Markdown
  def cook_html(html)
    cook_markdown(Markbridge.html_to_markdown(html).markdown)
  end

  # @param document [Markbridge::AST::Node]
  # @return [String] the HTML that markdown-it cooks from our Markdown
  def cook_ast(document)
    cook_markdown(Markbridge.render(document).markdown)
  end

  # @param markdown [String]
  # @return [String] the HTML markdown-it cooks from it
  def cook_markdown(markdown)
    MarkdownItCooker.cook(markdown)
  end

  # @param html [String] cooked HTML
  # @return [Nokogiri::HTML5::DocumentFragment]
  def fragment(html)
    Nokogiri::HTML5.fragment(html)
  end
end
