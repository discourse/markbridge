# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ItalicTag do
  let(:element_class) { Markbridge::AST::Italic }
  let(:empty_output) { "" }
  let(:simple_output) { "*hi*" }

  it_behaves_like "an inline wrapping tag"
end
