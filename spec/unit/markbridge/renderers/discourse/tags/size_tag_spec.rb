# frozen_string_literal: true

require "markbridge/rspec"

RSpec.describe Markbridge::Renderers::Discourse::Tags::SizeTag do
  include_context "with a renderer tag"

  def size(value, *children)
    element = Markbridge::AST::Size.new(size: value)
    children.each { |child| element << child }
    element
  end

  def text(value)
    Markbridge::AST::Text.new(value)
  end

  def rendered_by(tag, element, interface = self.interface)
    renderer.serialize(tag.render(element, interface), interface.context)
  end

  describe "#render" do
    context "when the bbcode feature is undecided (the default)" do
      it "raises for a size" do
        expect { tag.render(size("85", text("hi")), interface) }.to raise_error(
          Markbridge::UndecidedFeatureError,
          /a \[size\] tag needs a decision.*features: \{ bbcode: true \} with sizes:/,
        )
      end

      it "renders only the content when no size is set" do
        expect(rendered(size(nil, text("hi")))).to eq("hi")
        expect(rendered(size(" ", text("hi")))).to eq("hi")
      end

      it "renders only the content inside a link, where BBCode cannot go" do
        link = Markbridge::AST::Url.new(href: "https://example.com")

        expect(rendered(size("85", text("hi")), interface_for(link))).to eq("hi")
      end

      it "renders only the content inside an email link" do
        email = Markbridge::AST::Email.new(address: "a@example.com")

        expect(rendered(size("85", text("hi")), interface_for(email))).to eq("hi")
      end
    end

    context "with bbcode: false" do
      let(:tag) { described_class.new(bbcode: false) }

      it "renders only the content" do
        expect(rendered(size("85", text("hi")))).to eq("hi")
      end

      it "renders only the content in html_mode" do
        expect(rendered(size("85", text("hi")), interface_for(html_mode: true))).to eq("hi")
      end
    end

    context "with bbcode: true" do
      let(:tag) { described_class.new(bbcode: true) }

      it "writes [size] BBCode" do
        expect(rendered(size("85", text("hi")))).to eq("[size=85]hi[/size]")
      end

      # The closing tag would become part of the URL in front of it.
      it "writes a bare URL at the end as a link, and a comment after a URL in text" do
        url = Markbridge::AST::Url.new(href: "https://e.com/a")

        expect(rendered(size("85", text("see "), url))).to eq(
          "[size=85]see [https://e.com/a](https://e.com/a)[/size]",
        )
        expect(rendered(size("85", text("https://e.com/a")))).to eq(
          "[size=85]https://e.com/a<!---->[/size]",
        )
      end

      it "accepts whole numbers from 1 to 999, also as Integer" do
        %w[1 9 10 200 999].each do |value|
          expect(rendered(size(value, text("a")))).to eq("[size=#{value}]a[/size]")
        end
        expect(rendered(size(150, text("a")))).to eq("[size=150]a[/size]")
      end

      it "raises for a value that is not a size from 1 to 999" do
        ["0", "05", "1000", "-1", "+2", "1.5", "20px", "85%", "85 ", "x]y", "large"].each do |value|
          expect { tag.render(size(value, text("hi")), interface) }.to raise_error(
            ArgumentError,
            /size #{Regexp.escape(value.inspect)} maps to .* 1 to 999/,
          ),
          value
        end
      end

      it "renders only the content when no size is set" do
        expect(rendered(size(nil, text("hi")))).to eq("hi")
        expect(rendered(size("", text("hi")))).to eq("hi")
      end

      it "wraps every paragraph on its own" do
        expect(rendered(size("85", text("a\n\nb")))).to eq("[size=85]a[/size]\n\n[size=85]b[/size]")
      end

      it "renders only the content inside a link" do
        link = Markbridge::AST::Url.new(href: "https://example.com")

        expect(rendered(size("85", text("hi")), interface_for(link))).to eq("hi")
      end

      context "with a Hash as sizes:" do
        let(:tag) do
          described_class.new(bbcode: true, sizes: { "3" => 100, "7" => 300, "x" => nil })
        end

        it "writes the mapped percent" do
          expect(rendered(size("7", text("hi")))).to eq("[size=300]hi[/size]")
        end

        it "raises KeyError for a value the Hash does not know" do
          expect { tag.render(size("4", text("hi")), interface) }.to raise_error(KeyError)
        end

        it "renders only the content for a value mapped to nil" do
          expect(rendered(size("x", text("hi")))).to eq("hi")
        end
      end

      context "with a callable as sizes:" do
        let(:tag) { described_class.new(bbcode: true, sizes: ->(value) { Integer(value) * 10 }) }

        it "writes what the callable returns" do
          expect(rendered(size("8", text("hi")))).to eq("[size=80]hi[/size]")
        end

        it "raises when the callable returns something that is not a size" do
          expect { tag.render(size("100", text("hi")), interface) }.to raise_error(
            ArgumentError,
            /size "100" maps to 1000/,
          )
        end
      end

      context "in html_mode" do
        let(:context) { html_context }

        it "writes the span style that the discourse-bbcode plugin lets through" do
          expect(rendered(size("85", text("hi")))).to eq('<span style="font-size:85%">hi</span>')
        end

        it "writes a line break at the start as <br>, so the span is not alone on its line" do
          expect(rendered(size("85", Markbridge::AST::LineBreak.new, text("hi")))).to eq(
            '<span style="font-size:85%"><br>hi</span>',
          )
        end
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
