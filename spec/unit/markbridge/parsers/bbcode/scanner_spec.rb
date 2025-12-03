# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Scanner do
  def scan(input)
    scanner = described_class.new(input)
    tokens = []
    while (token = scanner.next_token)
      tokens << token
    end
    tokens
  end

  describe "#next_token" do
    it "returns tokens sequentially" do
      scanner = described_class.new("[b]text[/b]")
      tokens = []
      while (t = scanner.next_token)
        tokens << t
      end

      expect(tokens.size).to eq(3)
      expect(tokens[0]).to match_tag_start("b")
      expect(tokens[1]).to match_text_token("text")
      expect(tokens[2]).to match_tag_end("b")
    end

    it "returns nil at end of input" do
      scanner = described_class.new("")
      expect(scanner.next_token).to be_nil
    end
  end

  describe "plain text" do
    it "scans plain text" do
      tokens = scan("hello world")

      expect(tokens.size).to eq(1)
      expect(tokens[0]).to match_text_token("hello world")
    end

    it "handles empty input" do
      tokens = scan("")
      expect(tokens).to be_empty
    end
  end

  describe "simple tags" do
    it "scans opening tag" do
      tokens = scan("[b]")

      expect(tokens.size).to eq(1)
      expect(tokens[0]).to match_tag_start("b")
    end

    it "scans closing tag" do
      tokens = scan("[/b]")

      expect(tokens.size).to eq(1)
      expect(tokens[0]).to match_tag_end("b")
    end

    it "scans tag with text" do
      tokens = scan("[b]bold[/b]")

      expect(tokens.size).to eq(3)
      expect(tokens[0]).to match_tag_start("b")
      expect(tokens[1]).to match_text_token("bold")
      expect(tokens[2]).to match_tag_end("b")
    end

    it "normalizes tag names to lowercase" do
      tokens = scan("[BOLD]TEXT[/BOLD]")

      expect(tokens[0]).to match_tag_start("bold")
      expect(tokens[1]).to match_text_token("TEXT")
      expect(tokens[2]).to match_tag_end("bold")
    end
  end

  describe "tag attributes" do
    it "scans option attribute with =" do
      tokens = scan("[url=https://example.com]")

      expect(tokens.size).to eq(1)
      expect(tokens[0]).to match_tag_start("url", option: "https://example.com")
    end

    it "scans quoted option attribute" do
      tokens = scan('[quote="John Doe"]')

      expect(tokens[0]).to match_tag_start("quote", option: "John Doe")
    end

    it "scans single-quoted option attribute" do
      tokens = scan("[quote='Jane Smith']")

      expect(tokens[0]).to match_tag_start("quote", option: "Jane Smith")
    end

    it "scans named attributes" do
      tokens = scan(%q{[url href="https://example.com" title='Example']})

      expect(tokens[0]).to match_tag_start("url", href: "https://example.com", title: "Example")
    end

    it "scans option and named attributes together" do
      tokens = scan('[img=100x200 alt="Photo" title="My Photo"]')

      expect(tokens[0]).to match_tag_start(
        "img",
        option: "100x200",
        alt: "Photo",
        title: "My Photo",
      )
    end

    it "handles unquoted attribute values" do
      tokens = scan('[img alt=Photo title="My Photo" size=100x200]')

      expect(tokens[0]).to match_tag_start("img", alt: "Photo", title: "My Photo", size: "100x200")
    end
  end

  describe "special tag names" do
    it "scans tags with * (list item)" do
      tokens = scan("[*]")

      expect(tokens[0]).to match_tag_start("*")
    end

    it "scans tags with numbers" do
      tokens = scan("[h1]")

      expect(tokens[0]).to match_tag_start("h1")
    end

    it "scans tags with uid suffix" do
      tokens = scan("[quote:abc123]")

      expect(tokens[0]).to match_tag_start("quote:abc123")
    end
  end

  # ruby
  describe "nested tags" do
    it "scans simple nested tags" do
      tokens = scan("[b][i]text[/i][/b]")

      expect(tokens.size).to eq(5)
      expect(tokens[0]).to match_tag_start("b")
      expect(tokens[1]).to match_tag_start("i")
      expect(tokens[2]).to match_text_token("text")
      expect(tokens[3]).to match_tag_end("i")
      expect(tokens[4]).to match_tag_end("b")
    end

    it "scans nested tags with attributes and surrounding text" do
      tokens = scan("Before [quote='Alice'][b]hello[/b][/quote] After")

      expect(tokens[0]).to match_text_token("Before ")
      expect(tokens[1]).to match_tag_start("quote", option: "Alice")
      expect(tokens[2]).to match_tag_start("b")
      expect(tokens[3]).to match_text_token("hello")
      expect(tokens[4]).to match_tag_end("b")
      expect(tokens[5]).to match_tag_end("quote")
      expect(tokens[6]).to match_text_token(" After")
    end

    it "scans deep nesting" do
      tokens = scan("[a][b][c]x[/c][/b][/a]")

      expect(tokens.size).to eq(7)
      expect(tokens[0]).to match_tag_start("a")
      expect(tokens[1]).to match_tag_start("b")
      expect(tokens[2]).to match_tag_start("c")
      expect(tokens[3]).to match_text_token("x")
      expect(tokens[4]).to match_tag_end("c")
      expect(tokens[5]).to match_tag_end("b")
      expect(tokens[6]).to match_tag_end("a")
    end
  end

  describe "invalid tags" do
    it "treats incomplete tag as text" do
      tokens = scan("[incomplete")

      expect(tokens.size).to eq(2)
      expect(tokens[0]).to match_text_token("[")
      expect(tokens[1]).to match_text_token("incomplete")
    end

    it "treats tag with invalid name as text" do
      tokens = scan("[123]")

      expect(tokens.size).to eq(2)
      expect(tokens[0]).to match_text_token("[")
      expect(tokens[1]).to match_text_token("123]")
    end

    it "treats tag with spaces at start as text" do
      tokens = scan("[ b]")

      expect(tokens.size).to eq(2)
      expect(tokens[0]).to match_text_token("[")
      expect(tokens[1]).to match_text_token(" b]")
    end

    it "accepts tag with spaces after name" do
      tokens = scan("[b ]")

      expect(tokens.size).to eq(1)
      expect(tokens[0]).to match_tag_start("b")
    end
  end

  describe "text and tags mixed" do
    it "scans text before tag" do
      tokens = scan("Hello [b]world[/b]")

      expect(tokens[0]).to match_text_token("Hello ")
      expect(tokens[1]).to match_tag_start("b")
    end

    it "scans text after tag" do
      tokens = scan("[b]Hello[/b] world")

      expect(tokens[2]).to match_tag_end("b")
      expect(tokens[3]).to match_text_token(" world")
    end

    it "scans multiple tags" do
      tokens = scan("[b]bold[/b] and [i]italic[/i]")

      expect(tokens.size).to eq(7)
      expect(tokens[0]).to match_tag_start("b")
      expect(tokens[1]).to match_text_token("bold")
      expect(tokens[2]).to match_tag_end("b")
      expect(tokens[3]).to match_text_token(" and ")
      expect(tokens[4]).to match_tag_start("i")
      expect(tokens[5]).to match_text_token("italic")
      expect(tokens[6]).to match_tag_end("i")
    end
  end

  describe "edge cases" do
    it "handles literal [ not part of tag" do
      tokens = scan("Price: $[100]")

      expect(tokens.size).to eq(3)
      expect(tokens[0]).to match_text_token("Price: $")
      expect(tokens[1]).to match_text_token("[")
      expect(tokens[2]).to match_text_token("100]")
    end

    it "handles empty tag []" do
      tokens = scan("[]")

      expect(tokens.size).to eq(2)
      expect(tokens[0]).to match_text_token("[")
      expect(tokens[1]).to match_text_token("]")
    end
  end
end
