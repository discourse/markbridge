# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::MentionTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders an @-prefixed mention" do
      element = Markbridge::AST::Mention.new(name: "gerhard")

      expect(tag.render(element, interface)).to eq("@gerhard")
    end

    it "ignores the type and renders the same way for groups" do
      element = Markbridge::AST::Mention.new(name: "Testers", type: :group)

      expect(tag.render(element, interface)).to eq("@Testers")
    end

    it "HTML-escapes the name so it can be spliced into a raw HTML block" do
      element = Markbridge::AST::Mention.new(name: %(bad"<&>))

      expect(tag.render(element, interface)).to eq("@bad&quot;&lt;&amp;&gt;")
    end
  end
end
