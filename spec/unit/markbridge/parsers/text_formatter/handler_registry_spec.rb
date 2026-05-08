# frozen_string_literal: true

require "nokogiri"

RSpec.describe Markbridge::Parsers::TextFormatter::HandlerRegistry do
  let(:registry) { described_class.default }
  let(:parent) { Markbridge::AST::Document.new }
  let(:processor) do
    instance_double(Markbridge::Parsers::TextFormatter::Parser, process_children: nil)
  end

  def process_and_get_node(xml_string)
    xml = Nokogiri.XML(xml_string).root
    registry.process_element(xml, parent, processor)
    parent.children.last
  end

  describe "#process_element" do
    it "dispatches to the handler registered for the element's upcased name" do
      handler = instance_double(Markbridge::Parsers::TextFormatter::Handlers::BaseHandler)
      xml = Nokogiri.XML("<custom/>").root
      fake_node = Markbridge::AST::Text.new("x")
      registry.register("custom", handler)
      allow(handler).to receive(:process).with(element: xml, parent:, processor:).and_return(
        fake_node,
      )

      expect(registry.process_element(xml, parent, processor)).to eq(fake_node)
    end

    it "returns nil when no handler is registered for the element name" do
      xml = Nokogiri.XML("<UNKNOWN/>").root

      expect(registry.process_element(xml, parent, processor)).to be_nil
    end

    context "with default handlers" do
      it "dispatches B to a Bold-producing handler" do
        expect(process_and_get_node("<B>text</B>")).to be_a(Markbridge::AST::Bold)
      end

      it "dispatches I to an Italic-producing handler" do
        expect(process_and_get_node("<I>text</I>")).to be_a(Markbridge::AST::Italic)
      end

      it "dispatches U to an Underline-producing handler" do
        expect(process_and_get_node("<U>text</U>")).to be_a(Markbridge::AST::Underline)
      end

      it "dispatches S to a Strikethrough-producing handler" do
        expect(process_and_get_node("<S>text</S>")).to be_a(Markbridge::AST::Strikethrough)
      end

      it "dispatches URL to a Url-producing handler with href from url attribute" do
        node = process_and_get_node('<URL url="http://example.org">link</URL>')
        expect(node).to be_a(Markbridge::AST::Url)
        expect(node.href).to eq("http://example.org")
      end

      it "dispatches EMAIL to an Email-producing handler with address from email attribute" do
        node = process_and_get_node('<EMAIL email="a@b.c">email</EMAIL>')
        expect(node).to be_a(Markbridge::AST::Email)
        expect(node.address).to eq("a@b.c")
      end

      it "dispatches CODE to a Code-producing handler with language from lang attribute" do
        node = process_and_get_node('<CODE lang="ruby">code</CODE>')
        expect(node).to be_a(Markbridge::AST::Code)
        expect(node.language).to eq("ruby")
      end

      it "dispatches QUOTE to a Quote-producing handler with author from author attribute" do
        node = process_and_get_node('<QUOTE author="John">text</QUOTE>')
        expect(node).to be_a(Markbridge::AST::Quote)
        expect(node.author).to eq("John")
      end

      it "dispatches IMG to an Image-producing handler with src from src attribute" do
        node = process_and_get_node('<IMG src="http://example.org/image.jpg"/>')
        expect(node).to be_a(Markbridge::AST::Image)
        expect(node.src).to eq("http://example.org/image.jpg")
      end

      it "dispatches LIST to a List-producing handler" do
        node = process_and_get_node("<LIST><LI>item</LI></LIST>")
        expect(node).to be_a(Markbridge::AST::List)
      end

      it "dispatches LI to a ListItem-producing handler" do
        expect(process_and_get_node("<LI>item</LI>")).to be_a(Markbridge::AST::ListItem)
      end

      it "dispatches the asterisk element (non-XML name, registered directly) to a ListItem handler" do
        element = instance_double(Nokogiri::XML::Element, name: "*")

        result = registry.process_element(element, parent, processor)

        expect(result).to be_a(Markbridge::AST::ListItem)
        expect(parent.children.last).to eq(result)
      end

      it "dispatches P to a Paragraph-producing handler" do
        expect(process_and_get_node("<P>text</P>")).to be_a(Markbridge::AST::Paragraph)
      end

      it "dispatches COLOR to a Color-producing handler with color from color attribute" do
        node = process_and_get_node('<COLOR color="red">text</COLOR>')
        expect(node).to be_a(Markbridge::AST::Color)
        expect(node.color).to eq("red")
      end

      it "dispatches SIZE to a Size-producing handler with size from size attribute" do
        node = process_and_get_node('<SIZE size="150">text</SIZE>')
        expect(node).to be_a(Markbridge::AST::Size)
        expect(node.size).to eq("150")
      end

      it "dispatches ALIGN to an Align-producing handler, remapping align→alignment" do
        node = process_and_get_node('<ALIGN align="center">text</ALIGN>')
        expect(node).to be_a(Markbridge::AST::Align)
        expect(node.alignment).to eq("center")
      end

      it "dispatches SPOILER to a Spoiler-producing handler with title from title attribute" do
        node = process_and_get_node('<SPOILER title="hi">hidden</SPOILER>')
        expect(node).to be_a(Markbridge::AST::Spoiler)
        expect(node.title).to eq("hi")
      end

      it "dispatches ATTACHMENT to an Attachment-producing handler" do
        node = process_and_get_node('<ATTACHMENT id="123">file.pdf</ATTACHMENT>')
        expect(node).to be_a(Markbridge::AST::Attachment)
        expect(node.id).to eq("123")
      end

      it "dispatches ATTACH (alias) to an Attachment-producing handler" do
        node = process_and_get_node('<ATTACH id="456"/>')
        expect(node).to be_a(Markbridge::AST::Attachment)
        expect(node.id).to eq("456")
      end
    end

    context "with case insensitivity" do
      it "upcases the tag name before lookup" do
        expect(process_and_get_node("<b>text</b>")).to be_a(Markbridge::AST::Bold)
      end

      it "upcases mixed-case tag names before lookup" do
        expect(process_and_get_node("<Url>text</Url>")).to be_a(Markbridge::AST::Url)
      end
    end
  end

  describe "#has_handler?" do
    it "returns true when a handler is registered for the upcased tag name" do
      expect(registry.has_handler?("b")).to be true
      expect(registry.has_handler?("B")).to be true
      expect(registry.has_handler?("Url")).to be true
    end

    it "returns false when no handler is registered for the tag name" do
      expect(registry.has_handler?("UNKNOWN")).to be false
    end
  end

  describe "#register" do
    it "stores the handler under the upcased element name" do
      empty_registry = described_class.new
      handler = instance_double(Markbridge::Parsers::TextFormatter::Handlers::BaseHandler)

      empty_registry.register("custom", handler)

      expect(empty_registry.has_handler?("CUSTOM")).to be true
    end

    it "overrides an existing registration" do
      new_handler = instance_double(Markbridge::Parsers::TextFormatter::Handlers::BaseHandler)
      xml = Nokogiri.XML("<B/>").root
      replacement = Markbridge::AST::Text.new("replaced")
      registry.register("B", new_handler)
      allow(new_handler).to receive(:process).with(element: xml, parent:, processor:).and_return(
        replacement,
      )

      expect(registry.process_element(xml, parent, processor)).to eq(replacement)
    end
  end

  describe ".default" do
    let(:default_registry) { described_class.default }

    def handler_for(name)
      default_registry.instance_variable_get(:@mappings)[name]
    end

    {
      "B" => [Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler, Markbridge::AST::Bold],
      "I" => [Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler, Markbridge::AST::Italic],
      "U" => [
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler,
        Markbridge::AST::Underline,
      ],
      "S" => [
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler,
        Markbridge::AST::Strikethrough,
      ],
      "URL" => [Markbridge::Parsers::TextFormatter::Handlers::UrlHandler, Markbridge::AST::Url],
      "EMAIL" => [
        Markbridge::Parsers::TextFormatter::Handlers::EmailHandler,
        Markbridge::AST::Email,
      ],
      "CODE" => [Markbridge::Parsers::TextFormatter::Handlers::CodeHandler, Markbridge::AST::Code],
      "QUOTE" => [
        Markbridge::Parsers::TextFormatter::Handlers::QuoteHandler,
        Markbridge::AST::Quote,
      ],
      "IMG" => [Markbridge::Parsers::TextFormatter::Handlers::ImageHandler, Markbridge::AST::Image],
      "LIST" => [Markbridge::Parsers::TextFormatter::Handlers::ListHandler, Markbridge::AST::List],
      "LI" => [
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler,
        Markbridge::AST::ListItem,
      ],
      "*" => [
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler,
        Markbridge::AST::ListItem,
      ],
      "P" => [
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler,
        Markbridge::AST::Paragraph,
      ],
      "TABLE" => [
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler,
        Markbridge::AST::Table,
      ],
      "TR" => [
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler,
        Markbridge::AST::TableRow,
      ],
      "TD" => [
        Markbridge::Parsers::TextFormatter::Handlers::TableCellHandler,
        Markbridge::AST::TableCell,
      ],
      "TH" => [
        Markbridge::Parsers::TextFormatter::Handlers::TableCellHandler,
        Markbridge::AST::TableCell,
      ],
    }.each do |tag, (handler_class, element_class)|
      it "registers #{handler_class.name.split("::").last} producing #{element_class.name.split("::").last} for <#{tag}>" do
        registered = handler_for(tag)
        expect(registered).to be_a(handler_class)
        if registered.respond_to?(:element_class)
          expect(registered.element_class).to eq(element_class)
        end
      end
    end

    # AttributeHandler-based registrations — exercise the attribute arg.
    it "registers AttributeHandler(:color) for <COLOR>" do
      handler = handler_for("COLOR")
      expect(handler).to be_a(Markbridge::Parsers::TextFormatter::Handlers::AttributeHandler)
      expect(handler.element_class).to eq(Markbridge::AST::Color)
      expect(handler.instance_variable_get(:@attribute)).to eq(:color)
    end

    it "registers AttributeHandler(:size) for <SIZE>" do
      handler = handler_for("SIZE")
      expect(handler).to be_a(Markbridge::Parsers::TextFormatter::Handlers::AttributeHandler)
      expect(handler.element_class).to eq(Markbridge::AST::Size)
      expect(handler.instance_variable_get(:@attribute)).to eq(:size)
    end

    it "registers AttributeHandler(:align, param: :alignment) for <ALIGN>" do
      handler = handler_for("ALIGN")
      expect(handler).to be_a(Markbridge::Parsers::TextFormatter::Handlers::AttributeHandler)
      expect(handler.element_class).to eq(Markbridge::AST::Align)
      expect(handler.instance_variable_get(:@attribute)).to eq(:align)
      expect(handler.instance_variable_get(:@param)).to eq(:alignment)
    end

    it "registers AttributeHandler(:title) for <SPOILER>" do
      handler = handler_for("SPOILER")
      expect(handler).to be_a(Markbridge::Parsers::TextFormatter::Handlers::AttributeHandler)
      expect(handler.element_class).to eq(Markbridge::AST::Spoiler)
      expect(handler.instance_variable_get(:@attribute)).to eq(:title)
    end

    it "registers AttachmentHandler for both ATTACH and ATTACHMENT" do
      expect(handler_for("ATTACH")).to be_a(
        Markbridge::Parsers::TextFormatter::Handlers::AttachmentHandler,
      )
      expect(handler_for("ATTACHMENT")).to be_a(
        Markbridge::Parsers::TextFormatter::Handlers::AttachmentHandler,
      )
    end

    it "registers the asterisk (*) key directly, not the literal string \"*\".upcase" do
      # Ruby upcases "*" to "*" — included here to pin the literal key.
      expect(default_registry.has_handler?("*")).to be(true)
    end
  end

  describe ".build_from_default" do
    it "yields the default registry for customization" do
      custom = described_class.build_from_default { |r| r.register("CUSTOM", :fake) }

      expect(custom.has_handler?("CUSTOM")).to be true
      expect(custom.has_handler?("B")).to be true
    end

    it "returns the default registry unchanged when no block is given" do
      registry = described_class.build_from_default

      expect(registry.has_handler?("B")).to be true
    end
  end

  describe "#[]" do
    it "returns the handler bound to an element name (case-insensitive)" do
      registry = described_class.default
      expect(registry["b"]).to be_a(Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler)
      expect(registry["B"]).to be(registry["b"])
    end

    it "returns nil when no handler is bound" do
      expect(described_class.new["never-seen"]).to be_nil
    end
  end

  describe "#overlay" do
    let(:registry) { described_class.default }

    it "yields the previously bound handler" do
      seen = nil
      registry.overlay("URL") { |p| seen = p }
      expect(seen).to be_a(Markbridge::Parsers::TextFormatter::Handlers::UrlHandler)
    end

    it "yields nil for unbound names" do
      seen = :unset
      registry.overlay("NEVER-SEEN") do |p|
        seen = p
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler.new(Markbridge::AST::Bold)
      end
      expect(seen).to be_nil
    end

    it "registers whatever the block returns" do
      replacement =
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler.new(Markbridge::AST::Italic)

      registry.overlay("URL") { |_| replacement }

      expect(registry["URL"]).to be(replacement)
    end

    it "iterates over an Array of names" do
      replacement =
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler.new(Markbridge::AST::Italic)

      registry.overlay(%w[URL EMAIL]) { |_| replacement }

      expect(registry["URL"]).to be(replacement)
      expect(registry["EMAIL"]).to be(replacement)
    end

    it "returns self for chaining" do
      expect(registry.overlay("URL") { |p| p }).to be(registry)
    end
  end
end
