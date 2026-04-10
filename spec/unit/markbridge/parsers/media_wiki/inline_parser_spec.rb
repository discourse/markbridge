# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::MediaWiki::InlineParser do
  let(:parser) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def parse(text)
    parser.parse(text, parent:)
    parent
  end

  describe "plain text" do
    it "parses plain text" do
      doc = parse("hello world")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("hello world")
    end

    it "handles empty string" do
      doc = parse("")
      expect(doc.children).to be_empty
    end
  end

  describe "bold" do
    it "parses '''bold''' text" do
      doc = parse("'''bold'''")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Bold)
      expect(doc.children.first.children.first.text).to eq("bold")
    end

    it "parses bold within text" do
      doc = parse("before '''bold''' after")
      expect(doc.children.size).to eq(3)
      expect(doc.children[0].text).to eq("before ")
      expect(doc.children[1]).to be_a(Markbridge::AST::Bold)
      expect(doc.children[2].text).to eq(" after")
    end

    it "treats unclosed bold as text" do
      doc = parse("'''unclosed")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("'''unclosed")
    end
  end

  describe "italic" do
    it "parses ''italic'' text" do
      doc = parse("''italic''")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first).to be_a(Markbridge::AST::Italic)
      expect(doc.children.first.children.first.text).to eq("italic")
    end

    it "treats unclosed italic as text" do
      doc = parse("''unclosed")
      expect(doc.children.size).to eq(1)
      expect(doc.children.first.text).to eq("''unclosed")
    end
  end

  describe "bold italic" do
    it "parses '''''bold italic''''' text" do
      doc = parse("'''''bold italic'''''")
      expect(doc.children.size).to eq(1)

      bold = doc.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)

      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("bold italic")
    end
  end

  describe "internal links" do
    it "parses [[Page Name]]" do
      doc = parse("[[Page Name]]")
      expect(doc.children.size).to eq(1)

      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("Page Name")
      expect(url.children.first.text).to eq("Page Name")
    end

    it "parses [[Page Name|display text]]" do
      doc = parse("[[Page Name|display text]]")
      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("Page Name")
      expect(url.children.first.text).to eq("display text")
    end

    it "treats unclosed [[ as text" do
      doc = parse("[[unclosed link")
      expect(doc.children.first.text).to eq("[[unclosed link")
    end
  end

  describe "external links" do
    it "parses [url display text]" do
      doc = parse("[https://example.com Example]")
      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("https://example.com")
      expect(url.children.first.text).to eq("Example")
    end

    it "parses [url] without display text" do
      doc = parse("[https://example.com]")
      url = doc.children.first
      expect(url).to be_a(Markbridge::AST::Url)
      expect(url.href).to eq("https://example.com")
      expect(url.children.first.text).to eq("https://example.com")
    end

    it "treats unclosed [ as text" do
      doc = parse("[unclosed")
      expect(doc.children.first.text).to eq("[unclosed")
    end
  end

  describe "HTML tags" do
    it "parses <code>...</code>" do
      doc = parse("<code>some code</code>")
      code = doc.children.first
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children.first.text).to eq("some code")
    end

    it "parses <nowiki>...</nowiki> as literal text" do
      doc = parse("<nowiki>'''not bold'''</nowiki>")
      expect(doc.children.first).to be_a(Markbridge::AST::Text)
      expect(doc.children.first.text).to eq("'''not bold'''")
    end

    it "parses <br> as line break" do
      doc = parse("before<br>after")
      expect(doc.children.size).to eq(3)
      expect(doc.children[0].text).to eq("before")
      expect(doc.children[1]).to be_a(Markbridge::AST::LineBreak)
      expect(doc.children[2].text).to eq("after")
    end

    it "parses <br /> as line break" do
      doc = parse("before<br />after")
      expect(doc.children.size).to eq(3)
      expect(doc.children[1]).to be_a(Markbridge::AST::LineBreak)
    end

    it "parses <s>...</s> as strikethrough" do
      doc = parse("<s>deleted</s>")
      expect(doc.children.first).to be_a(Markbridge::AST::Strikethrough)
      expect(doc.children.first.children.first.text).to eq("deleted")
    end

    it "parses <del>...</del> as strikethrough" do
      doc = parse("<del>deleted</del>")
      expect(doc.children.first).to be_a(Markbridge::AST::Strikethrough)
    end

    it "parses <u>...</u> as underline" do
      doc = parse("<u>underlined</u>")
      expect(doc.children.first).to be_a(Markbridge::AST::Underline)
      expect(doc.children.first.children.first.text).to eq("underlined")
    end

    it "parses <ins>...</ins> as underline" do
      doc = parse("<ins>inserted</ins>")
      expect(doc.children.first).to be_a(Markbridge::AST::Underline)
    end

    it "parses <sup>...</sup> as superscript" do
      doc = parse("x<sup>2</sup>")
      expect(doc.children[1]).to be_a(Markbridge::AST::Superscript)
      expect(doc.children[1].children.first.text).to eq("2")
    end

    it "parses <sub>...</sub> as subscript" do
      doc = parse("H<sub>2</sub>O")
      expect(doc.children[1]).to be_a(Markbridge::AST::Subscript)
      expect(doc.children[1].children.first.text).to eq("2")
    end

    it "treats unknown HTML tags as text" do
      doc = parse("<span>text</span>")
      expect(doc.children.first.text).to eq("<span>text</span>")
    end
  end

  describe "nested inline markup" do
    it "parses italic inside bold" do
      doc = parse("'''text with ''italic'' inside'''")
      bold = doc.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children[1]).to be_a(Markbridge::AST::Italic)
      expect(bold.children[1].children.first.text).to eq("italic")
    end

    it "parses links inside bold" do
      doc = parse("'''[[Page|link]]'''")
      bold = doc.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.first).to be_a(Markbridge::AST::Url)
    end
  end

  describe "custom inline tag registry" do
    let(:registry) do
      Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
        r.register("mark", :formatting, Markbridge::AST::Bold)
      end
    end
    let(:parser) { described_class.new(inline_tag_registry: registry) }

    it "handles custom registered tags" do
      doc = parse("<mark>highlighted</mark>")
      expect(doc.children.first).to be_a(Markbridge::AST::Bold)
      expect(doc.children.first.children.first.text).to eq("highlighted")
    end

    it "still handles default tags" do
      doc = parse("<code>some code</code>")
      expect(doc.children.first).to be_a(Markbridge::AST::Code)
    end
  end

  describe "depth limiting" do
    it "stops recursion at MAX_INLINE_DEPTH and renders content as text" do
      parser = described_class.new(depth: described_class::MAX_INLINE_DEPTH - 1)
      parent = Markbridge::AST::Document.new
      parser.parse("'''bold'''", parent:)

      # At max depth, inner content should be plain text rather than recursed
      bold = parent.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children.first).to be_a(Markbridge::AST::Text)
      expect(bold.children.first.text).to eq("bold")
    end
  end
end
