# frozen_string_literal: true

require "markbridge/rspec"

RSpec.describe Markbridge::Renderers::Discourse::Tags::SizeTag do
  include_context "with a renderer tag"

  let(:bbcode_tag) { described_class.new(bbcode: true) }

  def size(value, *children)
    element = Markbridge::AST::Size.new(size: value)
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
      expect(rendered(size("85", text("hi")), interface)).to eq("hi")
    end

    it "writes [size] BBCode with bbcode: true" do
      expect(bbcode_rendered(size("85", text("hi")), interface)).to eq("[size=85]hi[/size]")
    end

    it "accepts whole numbers from 1 to 999" do
      %w[1 9 10 200 999].each do |value|
        expect(bbcode_rendered(size(value, text("a")), interface)).to eq("[size=#{value}]a[/size]")
      end
    end

    it "accepts an Integer value" do
      expect(bbcode_rendered(size(150, text("a")), interface)).to eq("[size=150]a[/size]")
    end

    it "renders only the content for a value that is not a size from 1 to 999" do
      [
        "0",
        "05",
        "1000",
        "-1",
        "+2",
        "1.5",
        "20px",
        "85%",
        "85 ",
        "x]y",
        "large",
        "",
      ].each do |value|
        expect(bbcode_rendered(size(value, text("hi")), interface)).to eq("hi"), value
      end
    end

    it "renders only the content when no size is set" do
      expect(bbcode_rendered(size(nil, text("hi")), interface)).to eq("hi")
    end

    it "wraps every paragraph on its own" do
      expect(bbcode_rendered(size("85", text("a\n\nb")), interface)).to eq(
        "[size=85]a[/size]\n\n[size=85]b[/size]",
      )
    end

    it "renders only the content inside a link" do
      link = Markbridge::AST::Url.new(href: "https://example.com")
      link_interface = interface_for(link)

      expect(bbcode_rendered(size("85", text("hi")), link_interface)).to eq("hi")
    end

    it "renders only the content inside an email link" do
      email = Markbridge::AST::Email.new(address: "a@example.com")
      email_interface = interface_for(email)

      expect(bbcode_rendered(size("85", text("hi")), email_interface)).to eq("hi")
    end

    context "in html_mode" do
      let(:context) { html_context }

      it "writes the span style that the discourse-bbcode plugin lets through" do
        expect(bbcode_rendered(size("85", text("hi")), interface)).to eq(
          '<span style="font-size:85%">hi</span>',
        )
      end

      it "writes a line break at the start as <br>, so the span is not alone on its line" do
        expect(bbcode_rendered(size("85", Markbridge::AST::LineBreak.new, text("hi")))).to eq(
          '<span style="font-size:85%"><br>hi</span>',
        )
      end

      it "renders only the content by default" do
        expect(rendered(size("85", text("hi")), interface)).to eq("hi")
      end
    end

    let(:element_class) { Markbridge::AST::Size }
    it_behaves_like "a tag that propagates parent context"
  end

  context "with bbcode: true" do
    it_behaves_like "an html_mode safe tag" do
      let(:tag) { described_class.new(bbcode: true) }
      let(:element) do
        Markbridge::AST::Size.new(size: "85") << (
          Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x")
        )
      end
    end
  end
end
