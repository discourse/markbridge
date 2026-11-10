# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::DeletionTag do
  let(:element_class) { Markbridge::AST::Deletion }
  let(:empty_output) { "<del></del>" }
  let(:simple_output) { "<del>hi</del>" }
  let(:html_simple_output) { "<del>hi</del>" }

  it_behaves_like "an inline wrapping tag"
end
