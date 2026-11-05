# frozen_string_literal: true

require "markbridge/rspec"

RSpec.describe Markbridge::Renderers::Discourse::Tags::ColorTag do
  include_context "with a renderer tag"

  let(:bbcode_tag) { described_class.new(bbcode: true) }

  def color(value, *children)
    element = Markbridge::AST::Color.new(color: value)
    children.each { |child| element << child }
    element
  end

  def text(value)
    Markbridge::AST::Text.new(value)
  end

  def bbcode_rendered(element, interface = self.interface)
    renderer.serialize(bbcode_tag.render(element, interface), interface.context)
  end

  describe "#render" do
    it "renders only the content by default" do
      expect(rendered(color("red", text("hi")), interface)).to eq("hi")
    end

    it "writes [color] BBCode with bbcode: true" do
      expect(bbcode_rendered(color("red", text("hi")), interface)).to eq("[color=red]hi[/color]")
    end

    it "accepts #rgb and #rrggbb values" do
      expect(bbcode_rendered(color("#f00", text("a")), interface)).to eq("[color=#f00]a[/color]")
      expect(bbcode_rendered(color("#FF0000", text("a")), interface)).to eq(
        "[color=#FF0000]a[/color]",
      )
    end

    it "renders only the content for a value that is not a color" do
      [
        "#ff",
        "#ff00",
        "#ff00000",
        "#ggg",
        "red;",
        "red ",
        "dark-red",
        "1",
        "x]y",
        "expression(x)",
        "",
      ].each do |value|
        expect(bbcode_rendered(color(value, text("hi")), interface)).to eq("hi"), value
      end
    end

    it "renders only the content when no color is set" do
      expect(bbcode_rendered(color(nil, text("hi")), interface)).to eq("hi")
    end

    it "wraps every paragraph on its own" do
      expect(bbcode_rendered(color("red", text("a\n\nb")), interface)).to eq(
        "[color=red]a[/color]\n\n[color=red]b[/color]",
      )
    end

    it "keeps edge whitespace outside of the BBCode" do
      expect(bbcode_rendered(color("red", text(" a ")), interface)).to eq(" [color=red]a[/color] ")
    end

    it "renders only the content inside a link" do
      link = Markbridge::AST::Url.new(href: "https://example.com")
      link_interface = interface_for(link)

      expect(bbcode_rendered(color("red", text("hi")), link_interface)).to eq("hi")
    end

    it "renders only the content inside an email link" do
      email = Markbridge::AST::Email.new(address: "a@example.com")
      email_interface = interface_for(email)

      expect(bbcode_rendered(color("red", text("hi")), email_interface)).to eq("hi")
    end

    context "in html_mode" do
      let(:context) { html_context }

      it "writes the span style that the discourse-bbcode plugin lets through" do
        expect(bbcode_rendered(color("red", text("hi")), interface)).to eq(
          '<span style="color:red">hi</span>',
        )
      end

      it "writes a line break at the start as <br>, so the span is not alone on its line" do
        expect(bbcode_rendered(color("red", Markbridge::AST::LineBreak.new, text("hi")))).to eq(
          '<span style="color:red"><br>hi</span>',
        )
      end

      it "renders only the content by default" do
        expect(rendered(color("red", text("hi")), interface)).to eq("hi")
      end
    end

    let(:element_class) { Markbridge::AST::Color }
    it_behaves_like "a tag that propagates parent context"
  end

  context "with bbcode: true" do
    it_behaves_like "an html_mode safe tag" do
      let(:tag) { described_class.new(bbcode: true) }
      let(:element) do
        Markbridge::AST::Color.new(color: "red") << (
          Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x")
        )
      end
    end
  end
end
