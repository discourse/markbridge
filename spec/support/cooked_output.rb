# frozen_string_literal: true

# commonmarker's Rust/Magnus native extension only builds on MRI.
require "commonmarker" if RUBY_ENGINE == "ruby"

# Helper for specs that check the HTML a CommonMark parser produces
# from our Markdown. Asserting on the Markdown alone lets a collapsed
# blank line pass unnoticed: the string still looks plausible while the
# content cooks to literal text.
#
# Include it in an example group and guard the group with
# +CookedOutput::SKIP_REASON+:
#
#     RSpec.describe "…", skip: CookedOutput::SKIP_REASON do
#       include CookedOutput
#     end
module CookedOutput
  SKIP_REASON = ("commonmarker not available on #{RUBY_ENGINE}" unless RUBY_ENGINE == "ruby")

  OPTIONS = { render: { unsafe: true }, extension: {} }.freeze

  # @param bbcode [String]
  # @return [String] the HTML that commonmarker cooks from our Markdown
  def cook(bbcode)
    Commonmarker.to_html(Markbridge.bbcode_to_markdown(bbcode).markdown, options: OPTIONS)
  end
end
