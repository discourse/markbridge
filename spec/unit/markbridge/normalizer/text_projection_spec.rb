# frozen_string_literal: true

RSpec.describe Markbridge::Normalizer::TextProjection do
  def project(node) = described_class.call(node)

  it "returns a Text node's own text" do
    expect(project(Markbridge::AST::Text.new("hello"))).to eq("hello")
  end

  it "returns a MarkdownText node's own text" do
    expect(project(Markbridge::AST::MarkdownText.new("**hi**"))).to eq("**hi**")
  end

  it "renders a Mention as its literal @name" do
    expect(project(Markbridge::AST::Mention.new(name: "alice"))).to eq("@alice")
  end

  it "concatenates the text of an Element's descendants" do
    bold = Markbridge::AST::Bold.new
    bold << Markbridge::AST::Text.new("a")
    bold << Markbridge::AST::Text.new("b")
    inner = Markbridge::AST::Italic.new
    inner << Markbridge::AST::Text.new("c")
    bold << inner

    expect(project(bold)).to eq("abc")
  end

  it "uses an opaque leaf's alt text when present" do
    upload = Markbridge::AST::Upload.new(sha1: "x", type: :image, alt: "a cat")
    expect(project(upload)).to eq("a cat")
  end

  it "falls back to raw when there is no alt" do
    upload = Markbridge::AST::Upload.new(sha1: "x", type: :image, raw: "![](upload://x)")
    expect(project(upload)).to eq("![](upload://x)")
  end

  it "projects to the empty string for an opaque leaf carrying no text" do
    expect(project(Markbridge::AST::HorizontalRule.new)).to eq("")
  end

  it "projects to the empty string when alt and raw are both nil" do
    # Upload responds to both :alt and :raw, but here they are nil — the
    # guards must fall through to "" rather than returning nil.
    expect(project(Markbridge::AST::Upload.new(sha1: "x"))).to eq("")
  end
end
