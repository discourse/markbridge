# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::SuperscriptTag do
  let(:element_class) { Markbridge::AST::Superscript }
  let(:empty_output) { "<sup></sup>" }
  let(:simple_output) { "<sup>hi</sup>" }
  let(:html_simple_output) { "<sup>hi</sup>" }

  it_behaves_like "an inline wrapping tag"
end
