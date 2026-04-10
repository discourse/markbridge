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

  describe "color and size wrapping structural elements" do
    it "converts color wrapping a list without leaking closing tags" do
      bbcode =
        "[color=green][b]Skill Name[/b]\n[list]\n[*]Level 2: Upgrade\n[*]Level 3: Upgrade\n[/list][/color]"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).not_to include("[/color]")
      expect(result).to include("**Skill Name**")
    end

    it "converts size wrapping a list without leaking closing tags" do
      bbcode = "[size=150][b]Title[/b]\n[list]\n[*]Item 1\n[*]Item 2\n[/list][/size]"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).not_to include("[/size]")
      expect(result).to include("**Title**")
    end

    it "converts color with bold inside list items" do
      bbcode = "[color=#FFBF00][b]Wolverine (X-Force)[/b][/color]"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).to eq('<span style="color: #FFBF00">**Wolverine (X-Force)**</span>')
    end

    it "converts nested color and list pattern from real forum data" do
      bbcode = <<~BBCODE.chomp
        [list][color=green][b]Godlike Power - Green 14[/b]
        Deals 203 damage to all enemies.
        [list]Level 2: Deals 266 damage.
        Level 3: Deals 331 damage.[/list][/color][/list]
      BBCODE

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result).not_to include("[/color]")
      expect(result).not_to include("[/list]")
      expect(result).to include("**Godlike Power - Green 14**")
    end
  end

  describe "urls" do
    it "converts url with href option" do
      result = Markbridge.bbcode_to_markdown("[url=https://example.com]Click here[/url]")
      expect(result).to eq("[Click here](https://example.com)")
    end

    it "converts url with content only (no href attribute)" do
      result = Markbridge.bbcode_to_markdown("[url]https://example.com[/url]")
      expect(result).to eq("https://example.com")
    end

    it "converts url with formatted content" do
      result = Markbridge.bbcode_to_markdown("[url=https://example.com][b]Bold link[/b][/url]")
      expect(result).to eq("[**Bold link**](https://example.com)")
    end
  end

  describe "images" do
    it "converts simple image" do
      result = Markbridge.bbcode_to_markdown("[img]https://example.com/photo.jpg[/img]")
      expect(result).to eq("![](https://example.com/photo.jpg)")
    end

    it "converts image with dimensions" do
      result = Markbridge.bbcode_to_markdown("[img=100x200]https://example.com/photo.jpg[/img]")
      expect(result).to eq("![|100x200](https://example.com/photo.jpg)")
    end

    it "converts image with width attribute" do
      result = Markbridge.bbcode_to_markdown("[img width=100]https://example.com/photo.jpg[/img]")
      expect(result).to eq("![|100](https://example.com/photo.jpg)")
    end
  end

  describe "quotes" do
    it "converts simple quote" do
      result = Markbridge.bbcode_to_markdown("[quote]Hello world[/quote]")
      expect(result).to eq("> Hello world")
    end

    it "converts quote with author" do
      result = Markbridge.bbcode_to_markdown("[quote=John]Hello world[/quote]")
      expect(result).to eq("[quote=\"John\"]\nHello world\n[/quote]")
    end

    it "converts quote with Discourse context" do
      result =
        Markbridge.bbcode_to_markdown('[quote="alice, post:123, topic:456"]Quoted text[/quote]')
      expect(result).to eq("[quote=\"alice, post:123, topic:456\"]\nQuoted text\n[/quote]")
    end
  end

  describe "strikethrough" do
    it "converts strikethrough tags" do
      result = Markbridge.bbcode_to_markdown("[s]deleted text[/s]")
      expect(result).to eq("~~deleted text~~")
    end

    it "converts strike alias" do
      result = Markbridge.bbcode_to_markdown("[strike]deleted[/strike]")
      expect(result).to eq("~~deleted~~")
    end
  end

  describe "underline" do
    it "converts underline to HTML" do
      result = Markbridge.bbcode_to_markdown("[u]underlined[/u]")
      expect(result).to eq("<u>underlined</u>")
    end
  end

  describe "superscript and subscript" do
    it "converts superscript to HTML" do
      result = Markbridge.bbcode_to_markdown("[sup]2[/sup]")
      expect(result).to eq("<sup>2</sup>")
    end

    it "converts subscript to HTML" do
      result = Markbridge.bbcode_to_markdown("[sub]2[/sub]")
      expect(result).to eq("<sub>2</sub>")
    end

    it "handles superscript in context" do
      result = Markbridge.bbcode_to_markdown("x[sup]2[/sup] + y[sup]3[/sup]")
      expect(result).to eq("x<sup>2</sup> \\+ y<sup>3</sup>")
    end
  end

  describe "spoiler" do
    it "converts simple spoiler" do
      result = Markbridge.bbcode_to_markdown("[spoiler]secret content[/spoiler]")
      expect(result).to eq("[spoiler]secret content[/spoiler]")
    end

    it "converts spoiler with title" do
      result = Markbridge.bbcode_to_markdown("[spoiler=Click to reveal]secret[/spoiler]")
      expect(result).to eq("\\[spoiler=Click to reveal]secret\\[/spoiler]")
    end

    it "converts hide alias" do
      result = Markbridge.bbcode_to_markdown("[hide]hidden content[/hide]")
      expect(result).to eq("[spoiler]hidden content[/spoiler]")
    end
  end

  describe "email" do
    it "converts email with address option" do
      result = Markbridge.bbcode_to_markdown("[email=user@example.com]Contact us[/email]")
      expect(result).to eq("[Contact us](mailto:user@example.com)")
    end

    it "converts email with content as address" do
      result = Markbridge.bbcode_to_markdown("[email]user@example.com[/email]")
      expect(result).to eq("user@example.com")
    end
  end

  describe "alignment" do
    it "converts center alignment" do
      result = Markbridge.bbcode_to_markdown("[center]centered text[/center]")
      expect(result).to eq('<div align="center">centered text</div>')
    end

    it "converts right alignment" do
      result = Markbridge.bbcode_to_markdown("[right]right-aligned[/right]")
      expect(result).to eq('<div align="right">right-aligned</div>')
    end
  end

  describe "edge cases" do
    it "drops unknown tag brackets but preserves content" do
      result = Markbridge.bbcode_to_markdown("[unknown]some text[/unknown]")
      expect(result).to eq("some text")
    end

    it "handles empty input" do
      result = Markbridge.bbcode_to_markdown("")
      expect(result).to eq("")
    end

    it "handles deeply nested formatting" do
      result = Markbridge.bbcode_to_markdown("[b][i][u]deep[/u][/i][/b]")
      expect(result).to eq("***<u>deep</u>***")
    end

    it "handles unclosed tags gracefully" do
      result = Markbridge.bbcode_to_markdown("[b]bold text")
      expect(result).to eq("**bold text**")
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

  describe "tables" do
    it "renders a simple table with headers as Markdown" do
      bbcode = "[table][tr][th]Name[/th][th]Age[/th][/tr][tr][td]Alice[/td][td]30[/td][/tr][/table]"

      result = Markbridge.bbcode_to_markdown(bbcode)

      expect(result).to eq("| Name | Age |\n| --- | --- |\n| Alice | 30 |")
    end

    it "renders a table without headers using first row as header" do
      bbcode = "[table][tr][td]A[/td][td]B[/td][/tr][tr][td]1[/td][td]2[/td][/tr][/table]"

      result = Markbridge.bbcode_to_markdown(bbcode)

      expect(result).to eq("| A | B |\n| --- | --- |\n| 1 | 2 |")
    end

    it "renders formatted content inside table cells" do
      bbcode = "[table][tr][th]Name[/th][/tr][tr][td][b]Alice[/b][/td][/tr][/table]"

      result = Markbridge.bbcode_to_markdown(bbcode)

      expect(result).to include("| **Alice** |")
    end

    it "falls back to HTML for uneven rows" do
      bbcode = "[table][tr][td]A[/td][td]B[/td][/tr][tr][td]1[/td][/tr][/table]"

      result = Markbridge.bbcode_to_markdown(bbcode)

      expect(result).to include("<table>")
      expect(result).to include("<td>A</td>")
    end
  end
end
