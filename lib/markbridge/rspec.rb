# frozen_string_literal: true

require_relative "../markbridge"

# Shared RSpec examples for consumers who write their own renderer
# tags. Require this file from your spec setup (RSpec itself must
# already be loaded):
#
#     require "markbridge/rspec"
#
# and put a custom tag under the html_mode contract:
#
#     RSpec.describe MyQuoteTag do
#       it_behaves_like "an html_mode safe tag" do
#         let(:tag) { described_class.new }
#         let(:element) do
#           element = MyQuote.new
#           element << Markbridge::AST::Text.new("body *with* sigils")
#           element
#         end
#       end
#     end
#
# The example renders +element+ with +tag+ in html_mode and fails when
# the output would break inside a CommonMark HTML block — the same
# check Markbridge runs against its own tags. Give +element+ children
# whose text contains Markdown sigils, so a tag that passes them
# through unprotected is caught. When the tag needs a customized
# renderer to resolve its children (for example a custom tag library),
# override +markbridge_renderer+ with your configured renderer.
RSpec.shared_examples "an html_mode safe tag" do
  let(:markbridge_renderer) { Markbridge::Renderers::Discourse::Renderer.new }

  let(:markbridge_html_mode_interface) do
    context = Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true)
    Markbridge::Renderers::Discourse::RenderingInterface.new(markbridge_renderer, context)
  end

  it "renders html_mode output that is safe inside an HTML block" do
    output = tag.render(element, markbridge_html_mode_interface)

    expect(Markbridge::Renderers::Discourse::HtmlBlockSafety.safe?(output)).to be(true),
    "Expected #{tag.class} to render raw HTML or a \\n\\n-wrapped " \
      "Markdown island in html_mode, got: #{output.inspect}"
  end
end
