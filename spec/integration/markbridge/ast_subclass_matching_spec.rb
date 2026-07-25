# frozen_string_literal: true

# End-to-end check that AST subclasses inherit normalizer rules and tag
# dispatch from their base class. This reproduces the original failure:
# a Code subclass with multi-line text inside Bold was neither hoisted
# (no rule matched the subclass) nor rendered as code (no tag matched),
# so its blank lines broke the surrounding ** markers.
RSpec.describe "AST subclass matching" do
  before { stub_const("LegacyCode", Class.new(Markbridge::AST::Code)) }

  def document_with_legacy_code_in_bold
    bold = Markbridge::AST::Bold.new
    bold << Markbridge::AST::Text.new("before")
    code = LegacyCode.new(language: "ruby")
    code << Markbridge::AST::Text.new("a\nb")
    bold << code
    Markbridge::AST::Document.new([bold])
  end

  it "hoists a multi-line Code subclass out of Bold and renders it as a fence" do
    conversion = Markbridge.render(document_with_legacy_code_in_bold)

    expect(conversion.markdown).to eq("**before**\n\n```ruby\na\nb\n```")
  end

  it "reports the normalization under the subclass's own name" do
    conversion = Markbridge.render(document_with_legacy_code_in_bold)

    expect(conversion.diagnostics[:normalization]).to eq(
      [{ parent: "Bold", child: "LegacyCode", strategy: :hoist_after, count: 1 }],
    )
  end

  it "keeps a single-line Code subclass inline, like the default Code rule" do
    bold = Markbridge::AST::Bold.new
    code = LegacyCode.new
    code << Markbridge::AST::Text.new("x = 1")
    bold << code
    document = Markbridge::AST::Document.new([bold])

    expect(Markbridge.render(document).markdown).to eq("**`x = 1`**")
  end

  it "renders an anonymous Bold subclass like Bold (intentional)" do
    node = Class.new(Markbridge::AST::Bold).new
    node << Markbridge::AST::Text.new("text")

    expect(Markbridge.render(node).markdown).to eq("**text**")
  end

  it "lets a rule registered for the subclass override the inherited one" do
    normalizer = Markbridge::Normalizer.default
    Markbridge::Normalizer::INLINE_CONTAINERS.each do |container|
      normalizer.rule(parent: container, child: LegacyCode, strategy: :drop)
    end

    conversion = Markbridge.render(document_with_legacy_code_in_bold, normalize: normalizer)

    expect(conversion.markdown).to eq("**before**")
  end
end
