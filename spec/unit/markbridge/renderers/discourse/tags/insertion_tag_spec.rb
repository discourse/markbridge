# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::InsertionTag do
  let(:element_class) { Markbridge::AST::Insertion }
  let(:empty_output) { "<ins></ins>" }
  let(:simple_output) { "<ins>hi</ins>" }
  let(:html_simple_output) { "<ins>hi</ins>" }

  it_behaves_like "an inline wrapping tag"
end
