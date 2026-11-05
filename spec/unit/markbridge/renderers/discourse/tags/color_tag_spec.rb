# frozen_string_literal: true

require "markbridge/rspec"

RSpec.describe Markbridge::Renderers::Discourse::Tags::ColorTag do
  include_context "with a renderer tag"

  def color(value, *children)
    element = Markbridge::AST::Color.new(color: value)
    children.each { |child| element << child }
    element
  end

  def text(value)
    Markbridge::AST::Text.new(value)
  end

  describe "#render" do
    context "when the bbcode feature is undecided (the default)" do
      it "raises for a color" do
        expect { tag.render(color("red", text("hi")), interface) }.to raise_error(
          Markbridge::UndecidedFeatureError,
          /a \[color\] tag needs a decision.*features: \{ bbcode: true \}/,
        )
      end

      it "renders only the content when no color is set" do
        expect(rendered(color(nil, text("hi")))).to eq("hi")
        expect(rendered(color("", text("hi")))).to eq("hi")
      end

      it "renders only the content inside a link, where BBCode cannot go" do
        link = Markbridge::AST::Url.new(href: "https://example.com")

        expect(rendered(color("red", text("hi")), interface_for(link))).to eq("hi")
      end

      it "renders only the content inside an email link" do
        email = Markbridge::AST::Email.new(address: "a@example.com")

        expect(rendered(color("red", text("hi")), interface_for(email))).to eq("hi")
      end
    end

    context "with bbcode: false" do
      let(:tag) { described_class.new(bbcode: false) }

      it "renders only the content" do
        expect(rendered(color("red", text("hi")))).to eq("hi")
      end

      it "renders only the content in html_mode" do
        expect(rendered(color("red", text("hi")), interface_for(html_mode: true))).to eq("hi")
      end
    end

    context "with bbcode: true" do
      let(:tag) { described_class.new(bbcode: true) }

      it "writes [color] BBCode" do
        expect(rendered(color("red", text("hi")))).to eq("[color=red]hi[/color]")
      end

      it "accepts #rgb and #rrggbb values" do
        expect(rendered(color("#f00", text("a")))).to eq("[color=#f00]a[/color]")
        expect(rendered(color("#FF0000", text("a")))).to eq("[color=#FF0000]a[/color]")
      end

      it "raises for a value that is not a color" do
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
        ].each do |value|
          expect { tag.render(color(value, text("hi")), interface) }.to raise_error(
            ArgumentError,
            /color #{Regexp.escape(value.inspect)} maps to .* #rgb, #rrggbb or a name/,
          ),
          value
        end
      end

      it "renders only the content when no color is set" do
        expect(rendered(color(nil, text("hi")))).to eq("hi")
      end

      it "wraps every paragraph on its own" do
        expect(rendered(color("red", text("a\n\nb")))).to eq(
          "[color=red]a[/color]\n\n[color=red]b[/color]",
        )
      end

      it "keeps edge whitespace outside of the BBCode" do
        expect(rendered(color("red", text(" a ")))).to eq(" [color=red]a[/color] ")
      end

      it "renders only the content inside a link" do
        link = Markbridge::AST::Url.new(href: "https://example.com")

        expect(rendered(color("red", text("hi")), interface_for(link))).to eq("hi")
      end

      context "with a Hash as colors:" do
        let(:tag) do
          described_class.new(
            bbcode: true,
            colors: {
              "dark-red" => "#8b0000",
              "warm" => :orange,
              "none" => nil,
            },
          )
        end

        it "writes the mapped color" do
          expect(rendered(color("dark-red", text("hi")))).to eq("[color=#8b0000]hi[/color]")
        end

        it "writes a Symbol from the mapping as a name" do
          expect(rendered(color("warm", text("hi")))).to eq("[color=orange]hi[/color]")
        end

        it "raises KeyError for a value the Hash does not know" do
          expect { tag.render(color("red", text("hi")), interface) }.to raise_error(KeyError)
        end

        it "renders only the content for a value mapped to nil" do
          expect(rendered(color("none", text("hi")))).to eq("hi")
        end
      end

      context "with a callable as colors:" do
        let(:tag) { described_class.new(bbcode: true, colors: ->(value) { value.delete(" ") }) }

        it "writes what the callable returns" do
          expect(rendered(color("re d", text("hi")))).to eq("[color=red]hi[/color]")
        end

        it "raises when the callable returns something that is not a color" do
          expect { tag.render(color("1 2", text("hi")), interface) }.to raise_error(
            ArgumentError,
            /color "1 2" maps to "12"/,
          )
        end
      end

      context "in html_mode" do
        let(:context) { html_context }

        it "writes the span style that the discourse-bbcode plugin lets through" do
          expect(rendered(color("red", text("hi")))).to eq('<span style="color:red">hi</span>')
        end

        it "writes a line break at the start as <br>, so the span is not alone on its line" do
          expect(rendered(color("red", Markbridge::AST::LineBreak.new, text("hi")))).to eq(
            '<span style="color:red"><br>hi</span>',
          )
        end
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
