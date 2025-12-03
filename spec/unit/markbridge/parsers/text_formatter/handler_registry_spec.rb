# frozen_string_literal: true

require "nokogiri"

RSpec.describe Markbridge::Parsers::TextFormatter::HandlerRegistry do
  let(:registry) { described_class.default }
  let(:parent) { Markbridge::AST::Document.new }

  # Helper method to process element and return the added node
  def process_and_get_node(xml_string)
    xml = Nokogiri.XML(xml_string).root
    registry.process_element(xml, parent)
    parent.children.last
  end

  describe "#process_element" do
    context "with formatting elements" do
      it "processes B element to Bold" do
        result = process_and_get_node("<B>text</B>")
        expect(result).to be_a(Markbridge::AST::Bold)
      end

      it "processes I element to Italic" do
        result = process_and_get_node("<I>text</I>")
        expect(result).to be_a(Markbridge::AST::Italic)
      end

      it "processes U element to Underline" do
        result = process_and_get_node("<U>text</U>")
        expect(result).to be_a(Markbridge::AST::Underline)
      end

      it "processes S element to Strikethrough" do
        result = process_and_get_node("<S>text</S>")
        expect(result).to be_a(Markbridge::AST::Strikethrough)
      end
    end

    context "with URL element" do
      it "processes URL element with url attribute" do
        result = process_and_get_node('<URL url="http://example.org">link</URL>')
        expect(result).to be_a(Markbridge::AST::Url)
        expect(result.href).to eq("http://example.org")
      end

      it "handles URL element without url attribute" do
        result = process_and_get_node("<URL>link</URL>")
        expect(result).to be_a(Markbridge::AST::Url)
        expect(result.href).to be_nil
      end
    end

    context "with EMAIL element" do
      it "processes EMAIL element with email attribute" do
        result = process_and_get_node('<EMAIL email="test@example.org">email</EMAIL>')
        expect(result).to be_a(Markbridge::AST::Email)
        expect(result.address).to eq("test@example.org")
      end

      it "handles EMAIL element without email attribute" do
        result = process_and_get_node("<EMAIL>test@example.org</EMAIL>")
        expect(result).to be_a(Markbridge::AST::Email)
        expect(result.address).to be_nil
      end
    end

    context "with CODE element" do
      it "processes CODE element with lang attribute" do
        result = process_and_get_node('<CODE lang="ruby">code</CODE>')
        expect(result).to be_a(Markbridge::AST::Code)
        expect(result.language).to eq("ruby")
      end

      it "processes CODE element with language attribute" do
        result = process_and_get_node('<CODE language="python">code</CODE>')
        expect(result).to be_a(Markbridge::AST::Code)
        expect(result.language).to eq("python")
      end

      it "handles CODE element without lang attribute" do
        result = process_and_get_node("<CODE>code</CODE>")
        expect(result).to be_a(Markbridge::AST::Code)
        expect(result.language).to be_nil
      end
    end

    context "with QUOTE element" do
      it "processes QUOTE element with author attribute" do
        result = process_and_get_node('<QUOTE author="John">text</QUOTE>')
        expect(result).to be_a(Markbridge::AST::Quote)
        expect(result.author).to eq("John")
      end

      it "processes QUOTE element with multiple attributes" do
        result =
          process_and_get_node('<QUOTE author="John" post_id="123" topic_id="456">text</QUOTE>')
        expect(result).to be_a(Markbridge::AST::Quote)
        expect(result.author).to eq("John")
        expect(result.post).to eq("123")
        expect(result.topic).to eq("456")
      end

      it "handles QUOTE element without attributes" do
        result = process_and_get_node("<QUOTE>text</QUOTE>")
        expect(result).to be_a(Markbridge::AST::Quote)
        expect(result.author).to be_nil
      end
    end

    context "with IMG element" do
      it "processes IMG element with src attribute" do
        result = process_and_get_node('<IMG src="http://example.org/image.jpg"/>')
        expect(result).to be_a(Markbridge::AST::Image)
        expect(result.src).to eq("http://example.org/image.jpg")
      end

      it "processes IMG element with src, width and height attributes" do
        result =
          process_and_get_node('<IMG src="http://example.org/image.jpg" width="100" height="200"/>')
        expect(result).to be_a(Markbridge::AST::Image)
        expect(result.src).to eq("http://example.org/image.jpg")
        expect(result.width).to eq(100)
        expect(result.height).to eq(200)
      end
    end

    context "with LIST element" do
      it "processes LIST element as unordered by default" do
        result = process_and_get_node("<LIST><LI>item</LI></LIST>")
        expect(result).to be_a(Markbridge::AST::List)
        expect(result.ordered?).to be false
      end

      it "processes LIST element with type=disc as unordered" do
        result = process_and_get_node('<LIST type="disc"><LI>item</LI></LIST>')
        expect(result).to be_a(Markbridge::AST::List)
        expect(result.ordered?).to be false
      end

      it "processes LIST element with type=1 as ordered" do
        result = process_and_get_node('<LIST type="1"><LI>item</LI></LIST>')
        expect(result).to be_a(Markbridge::AST::List)
        expect(result.ordered?).to be true
      end

      it "processes LIST element with type=a as ordered" do
        result = process_and_get_node('<LIST type="a"><LI>item</LI></LIST>')
        expect(result).to be_a(Markbridge::AST::List)
        expect(result.ordered?).to be true
      end
    end

    context "with LI element" do
      it "processes LI element to ListItem" do
        result = process_and_get_node("<LI>item</LI>")
        expect(result).to be_a(Markbridge::AST::ListItem)
      end
    end

    context "with COLOR element" do
      it "processes COLOR element with color attribute" do
        result = process_and_get_node('<COLOR color="red">text</COLOR>')
        expect(result).to be_a(Markbridge::AST::Color)
        expect(result.color).to eq("red")
      end

      it "handles COLOR element without color attribute" do
        result = process_and_get_node("<COLOR>text</COLOR>")
        expect(result).to be_a(Markbridge::AST::Color)
        expect(result.color).to be_nil
      end
    end

    context "with SIZE element" do
      it "processes SIZE element with size attribute" do
        result = process_and_get_node('<SIZE size="150">text</SIZE>')
        expect(result).to be_a(Markbridge::AST::Size)
        expect(result.size).to eq("150")
      end

      it "handles SIZE element without size attribute" do
        result = process_and_get_node("<SIZE>text</SIZE>")
        expect(result).to be_a(Markbridge::AST::Size)
        expect(result.size).to be_nil
      end
    end

    context "with ALIGN element" do
      it "processes ALIGN element with align attribute" do
        result = process_and_get_node('<ALIGN align="center">text</ALIGN>')
        expect(result).to be_a(Markbridge::AST::Align)
        expect(result.alignment).to eq("center")
      end

      it "handles ALIGN element without align attribute" do
        result = process_and_get_node("<ALIGN>text</ALIGN>")
        expect(result).to be_a(Markbridge::AST::Align)
        expect(result.alignment).to be_nil
      end
    end

    context "with SPOILER element" do
      it "processes SPOILER element with title attribute" do
        result = process_and_get_node('<SPOILER title="Click to reveal">hidden</SPOILER>')
        expect(result).to be_a(Markbridge::AST::Spoiler)
        expect(result.title).to eq("Click to reveal")
      end

      it "handles SPOILER element without title attribute" do
        result = process_and_get_node("<SPOILER>hidden</SPOILER>")
        expect(result).to be_a(Markbridge::AST::Spoiler)
        expect(result.title).to be_nil
      end
    end

    context "with ATTACHMENT element" do
      it "processes ATTACHMENT element with id attribute" do
        result = process_and_get_node('<ATTACHMENT id="123">file.pdf</ATTACHMENT>')
        expect(result).to be_a(Markbridge::AST::Attachment)
        expect(result.id).to eq("123")
      end

      it "processes ATTACH element with multiple attributes" do
        result =
          process_and_get_node('<ATTACH id="123" index="0" filename="file.pdf" alt="Document"/>')
        expect(result).to be_a(Markbridge::AST::Attachment)
        expect(result.id).to eq("123")
        expect(result.index).to eq("0")
        expect(result.filename).to eq("file.pdf")
        expect(result.alt).to eq("Document")
      end
    end

    context "with unknown element" do
      it "returns nil for unknown elements" do
        xml = Nokogiri.XML("<UNKNOWN>text</UNKNOWN>").root
        result = registry.process_element(xml, parent)
        expect(result).to be_nil
      end
    end

    context "with case sensitivity" do
      it "handles lowercase element names" do
        result = process_and_get_node("<b>text</b>")
        expect(result).to be_a(Markbridge::AST::Bold)
      end

      it "handles mixed case element names" do
        result = process_and_get_node("<Url>text</Url>")
        expect(result).to be_a(Markbridge::AST::Url)
      end
    end
  end

  describe "extensibility" do
    describe ".default" do
      it "returns registry with default handlers" do
        registry = described_class.default
        parent = Markbridge::AST::Document.new
        xml = Nokogiri.XML("<B>text</B>").root
        registry.process_element(xml, parent)
        expect(parent.children.first).to be_a(Markbridge::AST::Bold)
      end
    end

    describe ".build_from_default" do
      it "builds from defaults with custom additions using lambdas" do
        registry =
          described_class.build_from_default do |r|
            r.register(
              "CUSTOM",
              lambda do |element:, parent:|
                parent << Markbridge::AST::Text.new("custom")
                nil # Return nil - no children to process
              end,
            )
          end

        parent = Markbridge::AST::Document.new

        # Should have defaults
        xml = Nokogiri.XML("<B>text</B>").root
        registry.process_element(xml, parent)
        expect(parent.children.first).to be_a(Markbridge::AST::Bold)

        # Should have custom mapping
        xml = Nokogiri.XML("<CUSTOM>text</CUSTOM>").root
        registry.process_element(xml, parent)
        result = parent.children.last
        expect(result).to be_a(Markbridge::AST::Text)
        expect(result.text).to eq("custom")
      end

      it "allows overriding default mappings with handler objects" do
        custom_bold = Class.new(Markbridge::AST::Element)
        custom_handler =
          Class.new(Markbridge::Parsers::TextFormatter::Handlers::BaseHandler) do
            define_method(:initialize) { @element_class = custom_bold }

            define_method(:process) do |element:, parent:|
              node = custom_bold.new
              parent << node
              node # Return node to process children
            end

            define_method(:element_class) { @element_class }
          end

        registry = described_class.build_from_default { |r| r.register("B", custom_handler.new) }

        parent = Markbridge::AST::Document.new
        xml = Nokogiri.XML("<B>text</B>").root
        registry.process_element(xml, parent)
        expect(parent.children.first).to be_a(custom_bold)
      end
    end

    describe "#register" do
      it "registers custom element handlers using lambdas" do
        registry = described_class.new
        registry.register(
          "CUSTOM",
          lambda do |element:, parent:|
            attrs = {}
            element.attributes.each { |name, attr| attrs[name.downcase.to_sym] = attr.value }
            parent << Markbridge::AST::Text.new(attrs[:value] || "default")
            nil # Return nil - no children to process
          end,
        )

        parent = Markbridge::AST::Document.new
        xml = Nokogiri.XML('<CUSTOM value="test"/>').root
        registry.process_element(xml, parent)
        result = parent.children.first
        expect(result).to be_a(Markbridge::AST::Text)
        expect(result.text).to eq("test")
      end

      it "is case-insensitive" do
        registry = described_class.new
        registry.register(
          "custom",
          lambda do |element:, parent:|
            parent << Markbridge::AST::Text.new("works")
            nil # Return nil - no children to process
          end,
        )

        parent = Markbridge::AST::Document.new
        xml = Nokogiri.XML("<CUSTOM/>").root
        registry.process_element(xml, parent)
        expect(parent.children.first.text).to eq("works")
      end
    end
  end
end
