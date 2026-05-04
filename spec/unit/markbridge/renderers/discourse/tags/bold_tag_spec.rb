# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::BoldTag do
  let(:element_class) { Markbridge::AST::Bold }
  let(:empty_output) { "" }
  let(:simple_output) { "**hi**" }
  let(:html_simple_output) { "<strong>hi</strong>" }

  it_behaves_like "an inline wrapping tag"
end
