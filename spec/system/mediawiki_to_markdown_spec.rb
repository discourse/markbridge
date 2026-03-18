# frozen_string_literal: true

RSpec.describe "MediaWiki to Markdown Conversion" do
  describe "inline formatting" do
    it "converts bold text" do
      result = Markbridge.mediawiki_to_markdown("'''bold text'''")
      expect(result).to eq("**bold text**")
    end

    it "converts italic text" do
      result = Markbridge.mediawiki_to_markdown("''italic text''")
      expect(result).to eq("*italic text*")
    end

    it "converts bold italic text" do
      result = Markbridge.mediawiki_to_markdown("'''''bold italic'''''")
      expect(result).to eq("***bold italic***")
    end

    it "converts strikethrough with <s>" do
      result = Markbridge.mediawiki_to_markdown("<s>deleted</s>")
      expect(result).to eq("~~deleted~~")
    end

    it "converts strikethrough with <del>" do
      result = Markbridge.mediawiki_to_markdown("<del>deleted</del>")
      expect(result).to eq("~~deleted~~")
    end

    it "converts underline with <u>" do
      result = Markbridge.mediawiki_to_markdown("<u>underlined</u>")
      expect(result).to eq("<u>underlined</u>")
    end

    it "converts underline with <ins>" do
      result = Markbridge.mediawiki_to_markdown("<ins>inserted</ins>")
      expect(result).to eq("<u>inserted</u>")
    end

    it "converts superscript" do
      result = Markbridge.mediawiki_to_markdown("x<sup>2</sup>")
      expect(result).to eq("x<sup>2</sup>")
    end

    it "converts subscript" do
      result = Markbridge.mediawiki_to_markdown("H<sub>2</sub>O")
      expect(result).to eq("H<sub>2</sub>O")
    end

    it "converts inline code" do
      result = Markbridge.mediawiki_to_markdown("<code>var x = 1</code>")
      expect(result).to eq("`var x = 1`")
    end

    it "converts line break" do
      result = Markbridge.mediawiki_to_markdown("Line 1<br>Line 2")
      expect(result).to eq("Line 1\nLine 2")
    end

    it "converts self-closing line break" do
      result = Markbridge.mediawiki_to_markdown("Line 1<br />Line 2")
      expect(result).to eq("Line 1\nLine 2")
    end
  end

  describe "nowiki" do
    it "preserves wiki markup as literal text" do
      result = Markbridge.mediawiki_to_markdown("<nowiki>'''not bold'''</nowiki>")
      expect(result).to eq("'''not bold'''")
    end
  end

  describe "links" do
    it "converts external link with display text" do
      result = Markbridge.mediawiki_to_markdown("[https://example.com Click here]")
      expect(result).to eq("[Click here](https://example.com)")
    end

    it "converts external link without display text" do
      result = Markbridge.mediawiki_to_markdown("[https://example.com]")
      expect(result).to eq("[https://example.com](https://example.com)")
    end

    it "converts internal link" do
      result = Markbridge.mediawiki_to_markdown("[[Page Name]]")
      expect(result).to eq("Page Name")
    end

    it "converts internal link with display text" do
      result = Markbridge.mediawiki_to_markdown("[[Page Name|display text]]")
      expect(result).to eq("display text")
    end
  end

  describe "lists" do
    it "converts unordered list" do
      wiki = "* Item 1\n* Item 2\n* Item 3"

      result = Markbridge.mediawiki_to_markdown(wiki)
      expect(result).to eq("- Item 1\n- Item 2\n- Item 3")
    end

    it "converts ordered list" do
      wiki = "# First\n# Second\n# Third"

      result = Markbridge.mediawiki_to_markdown(wiki)
      expect(result).to eq("1. First\n1. Second\n1. Third")
    end

    it "converts nested unordered list" do
      wiki = "* Item 1\n** Subitem 1.1\n** Subitem 1.2\n* Item 2"

      result = Markbridge.mediawiki_to_markdown(wiki)
      expect(result).to include("- Item 1")
      expect(result).to include("- Subitem 1.1")
      expect(result).to include("- Item 2")
    end

    it "converts nested ordered list" do
      wiki = "# Item 1\n## Subitem 1.1\n## Subitem 1.2\n# Item 2"

      result = Markbridge.mediawiki_to_markdown(wiki)
      expect(result).to include("1. Item 1")
      expect(result).to include("1. Subitem 1.1")
      expect(result).to include("1. Item 2")
    end

    it "converts list items with formatting" do
      wiki = "* '''Important''' item\n* Normal item"

      result = Markbridge.mediawiki_to_markdown(wiki)
      expect(result).to eq("- **Important** item\n- Normal item")
    end
  end

  describe "horizontal rules" do
    it "converts ---- to horizontal rule" do
      result = Markbridge.mediawiki_to_markdown("----")
      expect(result).to eq("---")
    end

    it "converts longer dashes to horizontal rule" do
      result = Markbridge.mediawiki_to_markdown("------")
      expect(result).to eq("---")
    end
  end

  describe "preformatted text" do
    it "converts space-indented lines to code block" do
      wiki = " preformatted line 1\n preformatted line 2"

      result = Markbridge.mediawiki_to_markdown(wiki)
      expect(result).to eq("```\npreformatted line 1\npreformatted line 2\n```")
    end

    it "converts <pre> block to code block" do
      wiki = "<pre>code block\nline 2</pre>"

      result = Markbridge.mediawiki_to_markdown(wiki)
      expect(result).to eq("```\ncode block\nline 2\n```")
    end
  end

  describe "headings" do
    it "converts level 1 heading" do
      result = Markbridge.mediawiki_to_markdown("= Heading 1 =")
      expect(result).to eq("# Heading 1")
    end

    it "converts level 2 heading" do
      result = Markbridge.mediawiki_to_markdown("== Heading 2 ==")
      expect(result).to eq("## Heading 2")
    end

    it "converts level 3 heading" do
      result = Markbridge.mediawiki_to_markdown("=== Heading 3 ===")
      expect(result).to eq("### Heading 3")
    end

    it "converts heading with inline formatting" do
      result = Markbridge.mediawiki_to_markdown("== '''Bold''' heading ==")
      expect(result).to eq("## **Bold** heading")
    end
  end

  describe "edge cases" do
    it "handles empty input" do
      result = Markbridge.mediawiki_to_markdown("")
      expect(result).to eq("")
    end

    it "preserves plain text" do
      result = Markbridge.mediawiki_to_markdown("Just plain text")
      expect(result).to eq("Just plain text")
    end
  end
end
