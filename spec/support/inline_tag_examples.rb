# frozen_string_literal: true

# Shared examples for the inline formatting tags. A tag returns inline
# tokens or a String; +rendered+ writes them the way the renderer does.
# The examples check the simple output, the empty output, the html_mode
# output and that the tag puts itself on the parent chain for its
# children.
#
# Required `let`s in the including spec:
#   - element_class:       the AST::Element subclass the tag operates on
#   - empty_output:        what the tag returns for an empty element
#   - simple_output:       what the tag returns when the element wraps "hi"
#   - html_simple_output:  what the tag returns wrapping "hi" in html_mode
RSpec.shared_examples "an inline wrapping tag" do
  include_context "with a renderer tag"

  describe "#render" do
    it "returns the wrapped output for a simple text child" do
      element = element_class.new
      element << Markbridge::AST::Text.new("hi")

      expect(rendered(element)).to eq(simple_output)
    end

    it "returns the empty-content output when the element has no children" do
      element = element_class.new

      expect(rendered(element)).to eq(empty_output)
    end

    context "in html_mode" do
      let(:context) { html_context }

      it "returns the html-mode wrapped output for a simple text child" do
        element = element_class.new
        element << Markbridge::AST::Text.new("hi")

        expect(rendered(element)).to eq(html_simple_output)
      end
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
