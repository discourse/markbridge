# frozen_string_literal: true

# Shared examples for inline-formatting tags that wrap their children
# with fixed open/close markers and propagate themselves into the parent
# chain when rendering children.
#
# Required `let`s in the including spec:
#   - element_class:  the AST::Element subclass the tag operates on
#   - empty_output:   what the tag returns for an empty element
#   - simple_output:  what the tag returns when the element wraps "hi"
RSpec.shared_examples "an inline wrapping tag" do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "returns the wrapped output for a simple text child" do
      element = element_class.new
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq(simple_output)
    end

    it "returns the empty-content output when the element has no children" do
      element = element_class.new

      expect(tag.render(element, interface)).to eq(empty_output)
    end

    include_examples "a tag that propagates parent context"
  end
end

# Shared example covering the "interface.with_parent(element)" hook that
# almost every container tag uses to extend the parent chain when rendering
# children. Spec must define `element_class` (the AST::Element subclass)
# and may override `element_factory` to provide a constructed element.
RSpec.shared_examples "a tag that propagates parent context" do
  let(:propagation_element) { defined?(element_factory) ? element_factory : element_class.new }

  it "passes itself as the parent context when rendering children" do
    observed_parent = nil
    observed_class = element_class
    observer_tag =
      Class
        .new(Markbridge::Renderers::Discourse::Tag) do
          define_method(:render) do |_element, child_interface|
            observed_parent = child_interface.find_parent(observed_class)
            ""
          end
        end
        .new

    child_class = Class.new(Markbridge::AST::Element)
    library = Markbridge::Renderers::Discourse::TagLibrary.new
    library.register(element_class, described_class.new)
    library.register(child_class, observer_tag)
    custom_renderer = Markbridge::Renderers::Discourse::Renderer.new(tag_library: library)
    custom_interface =
      Markbridge::Renderers::Discourse::RenderingInterface.new(
        custom_renderer,
        Markbridge::Renderers::Discourse::RenderContext.new,
      )

    propagation_element << child_class.new

    described_class.new.render(propagation_element, custom_interface)

    expect(observed_parent).to eq(propagation_element)
  end
end
