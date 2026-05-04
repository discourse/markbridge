# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::StrikethroughTag do
  let(:element_class) { Markbridge::AST::Strikethrough }
  let(:empty_output) { "" }
  let(:simple_output) { "~~hi~~" }
  let(:html_simple_output) { "<s>hi</s>" }

  it_behaves_like "an inline wrapping tag"
end
