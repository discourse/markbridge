# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::SubscriptTag do
  let(:element_class) { Markbridge::AST::Subscript }
  let(:empty_output) { "<sub></sub>" }
  let(:simple_output) { "<sub>hi</sub>" }

  it_behaves_like "an inline wrapping tag"
end
