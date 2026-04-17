# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UnderlineTag do
  let(:element_class) { Markbridge::AST::Underline }
  let(:empty_output) { "<u></u>" }
  let(:simple_output) { "<u>hi</u>" }

  it_behaves_like "an inline wrapping tag"
end
