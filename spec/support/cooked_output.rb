# frozen_string_literal: true

require_relative "markdown_it_cooker"

# Helper for specs that check the HTML markdown-it cooks from our
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
    MarkdownItCooker.cook(Markbridge.bbcode_to_markdown(bbcode).markdown)
  end

  # @param html [String]
  # @return [String] the HTML that markdown-it cooks from our Markdown
  def cook_html(html)
    MarkdownItCooker.cook(Markbridge.html_to_markdown(html).markdown)
  end
end
