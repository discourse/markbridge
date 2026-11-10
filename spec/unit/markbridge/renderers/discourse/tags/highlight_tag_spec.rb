# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::HighlightTag do
  let(:element_class) { Markbridge::AST::Highlight }
  let(:empty_output) { "<mark></mark>" }
  let(:simple_output) { "<mark>hi</mark>" }
  let(:html_simple_output) { "<mark>hi</mark>" }

  it_behaves_like "an inline wrapping tag"
end
