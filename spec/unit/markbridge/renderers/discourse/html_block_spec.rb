# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::HtmlBlock do
  describe ".opens?" do
    it "accepts an opening block tag" do
      expect(described_class.opens?("<div>")).to be(true)
    end

    it "accepts a closing block tag" do
      expect(described_class.opens?("</div>")).to be(true)
    end

    it "accepts a tag with attributes" do
      expect(described_class.opens?(%(<div align="center">))).to be(true)
    end

    it "accepts a self-closing tag" do
      expect(described_class.opens?("<hr/>")).to be(true)
    end

    it "accepts a bare tag name at the end of the line" do
      expect(described_class.opens?("<table")).to be(true)
    end

    it "accepts a tag name followed by a space" do
      expect(described_class.opens?("<table class")).to be(true)
    end

    it "accepts a tag name followed by a tab" do
      expect(described_class.opens?("<table\tclass")).to be(true)
    end

    it "ignores the case of the tag name" do
      expect(described_class.opens?("<DIV>")).to be(true)
    end

    it "accepts a line indented beyond the three spaces the spec allows" do
      expect(described_class.opens?("      <div>")).to be(true)
    end

    it "accepts a line indented with a tab" do
      expect(described_class.opens?("\t<div>")).to be(true)
    end

    it "rejects an inline tag that starts no block" do
      expect(described_class.opens?("<span>x</span>")).to be(false)
    end

    it "rejects a block tag name that only starts the line's first word" do
      expect(described_class.opens?("<divider>")).to be(false)
    end

    it "rejects an autolink" do
      expect(described_class.opens?("<https://example.com>")).to be(false)
    end

    it "rejects a tag that does not start the line" do
      expect(described_class.opens?("text <div>")).to be(false)
    end

    it "rejects an empty line" do
      expect(described_class.opens?("")).to be(false)
    end
  end

  describe ".island" do
    it "surrounds the Markdown with blank lines" do
      expect(described_class.island("- a")).to eq("\n\n- a\n\n")
    end

    it "folds blank lines the fragment already has at its edges into the wrap" do
      expect(described_class.island("\n\n- a\n\n")).to eq("\n\n- a\n\n")
    end

    it "folds edge lines that hold only spaces or tabs" do
      expect(described_class.island("  \n\t\n- a\n  \n")).to eq("\n\n- a\n\n")
    end

    it "keeps the indentation of the first content line" do
      expect(described_class.island("\n  - a\n")).to eq("\n\n  - a\n\n")
    end

    it "keeps trailing spaces on a content line" do
      expect(described_class.island("  padded  ")).to eq("\n\n  padded  \n\n")
    end

    it "keeps blank lines inside the Markdown" do
      expect(described_class.island("a\n\nb")).to eq("\n\na\n\nb\n\n")
    end
  end

  describe ".safe?" do
    it "accepts an empty string" do
      expect(described_class.safe?("")).to be(true)
    end

    it "accepts plain text without Markdown sigils" do
      expect(described_class.safe?("plain text")).to be(true)
    end

    it "accepts a raw HTML fragment" do
      expect(described_class.safe?("<strong>x</strong>")).to be(true)
    end

    it "rejects emphasis stars" do
      expect(described_class.safe?("**x**")).to be(false)
    end

    it "rejects underscores" do
      expect(described_class.safe?("_x_")).to be(false)
    end

    it "rejects tildes" do
      expect(described_class.safe?("~x~")).to be(false)
    end

    it "rejects a link middle" do
      expect(described_class.safe?("[x](https://example.com)")).to be(false)
    end

    it "accepts a lone closing bracket" do
      expect(described_class.safe?("a] b")).to be(true)
    end

    it "accepts a lone opening parenthesis" do
      expect(described_class.safe?("a (b)")).to be(true)
    end

    it "accepts Markdown inside a blank-line wrapped island" do
      expect(described_class.safe?("\n\n**x**\n\n")).to be(true)
    end

    it "rejects Markdown when only the leading blank line is present" do
      expect(described_class.safe?("\n\n**x**")).to be(false)
    end

    it "rejects Markdown when only the trailing blank line is present" do
      expect(described_class.safe?("**x**\n\n")).to be(false)
    end

    it "rejects Markdown when the island starts with a single newline" do
      expect(described_class.safe?("\n**x**\n\n")).to be(false)
    end

    it "rejects Markdown when the island ends with a single newline" do
      expect(described_class.safe?("\n\n**x**\n")).to be(false)
    end
  end
end
