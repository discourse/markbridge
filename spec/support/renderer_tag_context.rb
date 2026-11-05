# frozen_string_literal: true

# The setup a renderer tag spec starts from: a tag of the described
# class, a renderer, a context without parents and the interface on it.
# A spec that renders in html_mode overrides +context+ with
# +html_context+. +interface_for+ builds an interface under the given
# parents, and +rendered+ writes what a tag returns, a String or inline
# tokens, the way the renderer does.
RSpec.shared_context "with a renderer tag" do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:html_context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  def interface_for(*parents, html_mode: false)
    parent_context = Markbridge::Renderers::Discourse::RenderContext.new(parents, html_mode:)
    Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, parent_context)
  end

  def rendered(element, interface = self.interface)
    renderer.serialize(tag.render(element, interface), interface.context)
  end
end
