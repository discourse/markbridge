# frozen_string_literal: true

RSpec.describe "BBCode to Markdown Conversion" do
  describe "nested lists" do
    describe "nested unordered lists" do
      it "renders with proper indentation" do
        bbcode = <<~BBCODE
          [list]
          [*]Item 1
          [*]Item 2
          [list]
          [*]Subitem 2.1
          [*]Subitem 2.2
          [/list]
          [*]Item 3
          [/list]
        BBCODE

        expected = <<~MARKDOWN.strip
          - Item 1
          - Item 2
            - Subitem 2.1
            - Subitem 2.2
          - Item 3
        MARKDOWN

        result = Markbridge.bbcode_to_markdown(bbcode)
        expect(result).to eq(expected)
      end

      it "handles deeply nested lists" do
        bbcode = <<~BBCODE
          [list]
          [*]Level 1
          [list]
          [*]Level 2
          [list]
          [*]Level 3
          [/list]
          [/list]
          [/list]
        BBCODE

        expected = <<~MARKDOWN.strip
          - Level 1
            - Level 2
              - Level 3
        MARKDOWN

        result = Markbridge.bbcode_to_markdown(bbcode)
        expect(result).to eq(expected)
      end
    end

    describe "nested ordered lists" do
      it "renders with proper indentation" do
        bbcode = <<~BBCODE
          [list=1]
          [*]Item 1
          [*]Item 2
          [list=1]
          [*]Subitem 2.1
          [*]Subitem 2.2
          [/list]
          [*]Item 3
          [/list]
        BBCODE

        expected = <<~MARKDOWN.strip
          1. Item 1
          1. Item 2
             1. Subitem 2.1
             1. Subitem 2.2
          1. Item 3
        MARKDOWN

        result = Markbridge.bbcode_to_markdown(bbcode)
        expect(result).to eq(expected)
      end
    end

    describe "mixed nested lists" do
      it "renders ordered inside unordered" do
        bbcode = <<~BBCODE
          [list]
          [*]Item 1
          [*]Item 2
          [list=1]
          [*]Subitem 2.1
          [*]Subitem 2.2
          [/list]
          [*]Item 3
          [/list]
        BBCODE

        expected = <<~MARKDOWN.strip
          - Item 1
          - Item 2
            1. Subitem 2.1
            1. Subitem 2.2
          - Item 3
        MARKDOWN

        result = Markbridge.bbcode_to_markdown(bbcode)
        expect(result).to eq(expected)
      end

      it "renders unordered inside ordered" do
        bbcode = <<~BBCODE
          [list=1]
          [*]Item 1
          [*]Item 2
          [list]
          [*]Subitem 2.1
          [*]Subitem 2.2
          [/list]
          [*]Item 3
          [/list]
        BBCODE

        expected = <<~MARKDOWN.strip
          1. Item 1
          1. Item 2
             - Subitem 2.1
             - Subitem 2.2
          1. Item 3
        MARKDOWN

        result = Markbridge.bbcode_to_markdown(bbcode)
        expect(result).to eq(expected)
      end
    end

    describe "lists with formatted content" do
      it "preserves formatting within list items" do
        bbcode = <<~BBCODE
          [list]
          [*][b]Bold item[/b]
          [*][i]Italic item[/i]
          [*][code]Code item[/code]
          [/list]
        BBCODE

        expected = <<~MARKDOWN.strip
          - **Bold item**
          - *Italic item*
          - `Code item`
        MARKDOWN

        result = Markbridge.bbcode_to_markdown(bbcode)
        expect(result).to eq(expected)
      end

      it "handles complex nested content in lists" do
        bbcode = <<~BBCODE
          [list]
          [*]Item with [b]bold[/b] and [i]italic[/i]
          [list]
          [*]Nested with [code]code[/code]
          [/list]
          [/list]
        BBCODE

        expected = <<~MARKDOWN.strip
          - Item with **bold** and *italic*
            - Nested with `code`
        MARKDOWN

        result = Markbridge.bbcode_to_markdown(bbcode)
        expect(result).to eq(expected)
      end
    end
  end

  describe "basic formatting" do
    it "converts bold tags" do
      result = Markbridge.bbcode_to_markdown("[b]bold text[/b]")
      expect(result).to eq("**bold text**")
    end

    it "converts italic tags" do
      result = Markbridge.bbcode_to_markdown("[i]italic text[/i]")
      expect(result).to eq("*italic text*")
    end

    it "converts code tags" do
      result = Markbridge.bbcode_to_markdown("[code]code text[/code]")
      expect(result).to eq("`code text`")
    end

    it "handles nested formatting" do
      result = Markbridge.bbcode_to_markdown("[b][i]bold italic[/i][/b]")
      expect(result).to eq("***bold italic***")
    end
  end

  describe "line breaks and horizontal rules" do
    it "converts line breaks" do
      result = Markbridge.bbcode_to_markdown("line 1[br]line 2")
      expect(result).to eq("line 1\nline 2")
    end

    it "converts horizontal rules" do
      result = Markbridge.bbcode_to_markdown("before[hr]after")
      expect(result).to eq("before\n\n---\n\nafter")
    end
  end

  describe "simple lists" do
    it "converts simple unordered list" do
      bbcode = <<~BBCODE
        [list]
        [*]Item 1
        [*]Item 2
        [*]Item 3
        [/list]
      BBCODE

      expected = <<~MARKDOWN.strip
        - Item 1
        - Item 2
        - Item 3
      MARKDOWN

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).to eq(expected)
    end

    it "converts simple ordered list" do
      bbcode = <<~BBCODE
        [list=1]
        [*]First
        [*]Second
        [*]Third
        [/list]
      BBCODE

      expected = <<~MARKDOWN.strip
        1. First
        1. Second
        1. Third
      MARKDOWN

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).to eq(expected)
    end
  end

  describe "mixed content" do
    it "handles text with multiple formatting types" do
      result =
        Markbridge.bbcode_to_markdown(
          "Plain text with [b]bold[/b] and [i]italic[/i] and [code]code[/code].",
        )
      expect(result).to eq("Plain text with **bold** and *italic* and `code`.")
    end

    it "preserves plain text" do
      result = Markbridge.bbcode_to_markdown("Just plain text")
      expect(result).to eq("Just plain text")
    end
  end

  describe "attachments" do
    it "converts attachment with numeric id (vBulletin/XenForo format)" do
      result = Markbridge.bbcode_to_markdown("[attach]1234[/attach]")
      expect(result).to eq("<!-- ATTACHMENT: id=1234 -->")
    end

    it "converts attachment with index and filename (phpBB format)" do
      result = Markbridge.bbcode_to_markdown("[attachment=0]image.jpg[/attachment]")
      expect(result).to eq("<!-- ATTACHMENT: index=0 filename=image.jpg -->")
    end

    it "converts attachment with index only (phpBB format)" do
      result = Markbridge.bbcode_to_markdown("[attachment=2][/attachment]")
      expect(result).to eq("<!-- ATTACHMENT: index=2 -->")
    end

    it "converts attachment with id and alt text (XenForo 2.1+ format)" do
      result = Markbridge.bbcode_to_markdown('[attach alt="diagram"]5678[/attach]')
      expect(result).to eq("<!-- ATTACHMENT: id=5678 alt=diagram -->")
    end

    it "converts self-closing attachment with SMF format" do
      result = Markbridge.bbcode_to_markdown("[attach id=2 msg=9876]")
      expect(result).to eq("<!-- ATTACHMENT: id=9876 index=2 -->")
    end

    it "converts attachment with filename only" do
      result = Markbridge.bbcode_to_markdown("[attach]document.pdf[/attach]")
      expect(result).to eq("<!-- ATTACHMENT: id=document.pdf -->")
    end

    it "handles attachment in context with text" do
      bbcode = "Check out this image: [attachment=0]screenshot.png[/attachment] for details."
      expected =
        "Check out this image: <!-- ATTACHMENT: index=0 filename=screenshot.png --> for details."

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).to eq(expected)
    end

    it "handles multiple attachments" do
      bbcode = "[attach]111[/attach] and [attach]222[/attach]"
      expected = "<!-- ATTACHMENT: id=111 --> and <!-- ATTACHMENT: id=222 -->"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).to eq(expected)
    end

    it "handles attachments in formatted text" do
      bbcode = "[b]Bold text with [attach]123[/attach] inside[/b]"
      expected = "**Bold text with <!-- ATTACHMENT: id=123 --> inside**"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).to eq(expected)
    end
  end
end
