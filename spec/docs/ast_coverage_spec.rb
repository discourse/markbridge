# frozen_string_literal: true

RSpec.describe "AST documentation coverage" do
  let(:doc_path) do
    SPEC_ROOT.join("..", "docs", "src", "content", "docs", "concepts", "ast.md").expand_path
  end
  let(:doc_content) { doc_path.read }

  # Every concrete-or-abstract Markbridge::AST::* class.
  let(:code_classes) do
    Markbridge::AST
      .constants
      .map { |c| Markbridge::AST.const_get(c) }
      .select { |c| c.is_a?(Class) && c <= Markbridge::AST::Node }
      .map { |c| c.name.split("::").last }
      .to_set
  end

  # `AST::Foo` mentions inside concepts/ast.md.
  let(:doc_classes) { doc_content.scan(/AST::([A-Z][A-Za-z]*)/).flatten.to_set }

  it "mentions every AST class under lib/markbridge/ast/" do
    missing = code_classes - doc_classes
    expect(missing).to be_empty,
    lambda {
      "AST classes missing from docs/src/content/docs/concepts/ast.md:\n  " +
        missing.to_a.sort.join("\n  ")
    }
  end

  it "doesn't reference AST classes that no longer exist" do
    stale = doc_classes - code_classes
    expect(stale).to be_empty,
    lambda {
      "docs/src/content/docs/concepts/ast.md references AST classes not present in lib/:\n  " +
        stale.to_a.sort.join("\n  ")
    }
  end
end
