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
        expect(result.markdown).to eq(expected)
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
        expect(result.markdown).to eq(expected)
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
        expect(result.markdown).to eq(expected)
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
        expect(result.markdown).to eq(expected)
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
        expect(result.markdown).to eq(expected)
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
        expect(result.markdown).to eq(expected)
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
        expect(result.markdown).to eq(expected)
      end
    end
  end

  describe "basic formatting" do
    it "converts bold tags" do
      result = Markbridge.bbcode_to_markdown("[b]bold text[/b]")
      expect(result.markdown).to eq("**bold text**")
    end

    it "converts italic tags" do
      result = Markbridge.bbcode_to_markdown("[i]italic text[/i]")
      expect(result.markdown).to eq("*italic text*")
    end

    it "converts code tags" do
      result = Markbridge.bbcode_to_markdown("[code]code text[/code]")
      expect(result.markdown).to eq("`code text`")
    end

    it "handles nested formatting" do
      result = Markbridge.bbcode_to_markdown("[b][i]bold italic[/i][/b]")
      expect(result.markdown).to eq("***bold italic***")
    end
  end

  describe "line breaks and horizontal rules" do
    it "converts line breaks" do
      result = Markbridge.bbcode_to_markdown("line 1[br]line 2")
      expect(result.markdown).to eq("line 1\nline 2")
    end

    it "converts horizontal rules" do
      result = Markbridge.bbcode_to_markdown("before[hr]after")
      expect(result.markdown).to eq("before\n\n---\n\nafter")
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
      expect(result.markdown).to eq(expected)
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
      expect(result.markdown).to eq(expected)
    end
  end

  describe "mixed content" do
    it "handles text with multiple formatting types" do
      result =
        Markbridge.bbcode_to_markdown(
          "Plain text with [b]bold[/b] and [i]italic[/i] and [code]code[/code].",
        )
      expect(result.markdown).to eq("Plain text with **bold** and *italic* and `code`.")
    end

    it "preserves plain text" do
      result = Markbridge.bbcode_to_markdown("Just plain text")
      expect(result.markdown).to eq("Just plain text")
    end
  end

  describe "color and size wrapping structural elements" do
    it "converts color wrapping a list without leaking closing tags" do
      bbcode =
        "[color=green][b]Skill Name[/b]\n[list]\n[*]Level 2: Upgrade\n[*]Level 3: Upgrade\n[/list][/color]"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result.markdown).not_to include("[/color]")
      expect(result.markdown).to include("**Skill Name**")
    end

    it "converts size wrapping a list without leaking closing tags" do
      bbcode = "[size=150][b]Title[/b]\n[list]\n[*]Item 1\n[*]Item 2\n[/list][/size]"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result.markdown).not_to include("[/size]")
      expect(result.markdown).to include("**Title**")
    end

    it "converts color with bold inside list items" do
      bbcode = "[color=#FFBF00][b]Wolverine (X-Force)[/b][/color]"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result.markdown).to eq('<span style="color: #FFBF00">**Wolverine (X-Force)**</span>')
    end

    it "converts nested color and list pattern from real forum data" do
      bbcode = <<~BBCODE.chomp
        [list][color=green][b]Godlike Power - Green 14[/b]
        Deals 203 damage to all enemies.
        [list]Level 2: Deals 266 damage.
        Level 3: Deals 331 damage.[/list][/color][/list]
      BBCODE

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result.markdown).not_to include("[/color]")
      expect(result.markdown).not_to include("[/list]")
      expect(result.markdown).to include("**Godlike Power - Green 14**")
    end
  end

  describe "urls" do
    it "converts url with href option" do
      result = Markbridge.bbcode_to_markdown("[url=https://example.com]Click here[/url]")
      expect(result.markdown).to eq("[Click here](https://example.com)")
    end

    it "converts url with content only (no href attribute)" do
      result = Markbridge.bbcode_to_markdown("[url]https://example.com[/url]")
      expect(result.markdown).to eq("https://example.com")
    end

    it "converts url with formatted content" do
      result = Markbridge.bbcode_to_markdown("[url=https://example.com][b]Bold link[/b][/url]")
      expect(result.markdown).to eq("[**Bold link**](https://example.com)")
    end
  end

  describe "images" do
    it "converts simple image" do
      result = Markbridge.bbcode_to_markdown("[img]https://example.com/photo.jpg[/img]")
      expect(result.markdown).to eq("![](https://example.com/photo.jpg)")
    end

    it "converts image with dimensions" do
      result = Markbridge.bbcode_to_markdown("[img=100x200]https://example.com/photo.jpg[/img]")
      expect(result.markdown).to eq("![|100x200](https://example.com/photo.jpg)")
    end

    it "converts image with width attribute" do
      result = Markbridge.bbcode_to_markdown("[img width=100]https://example.com/photo.jpg[/img]")
      expect(result.markdown).to eq("![|100](https://example.com/photo.jpg)")
    end
  end

  describe "quotes" do
    it "converts simple quote" do
      result = Markbridge.bbcode_to_markdown("[quote]Hello world[/quote]")
      expect(result.markdown).to eq("> Hello world")
    end

    it "converts quote with author" do
      result = Markbridge.bbcode_to_markdown("[quote=John]Hello world[/quote]")
      expect(result.markdown).to eq("[quote=\"John\"]\nHello world\n[/quote]")
    end

    it "converts quote with Discourse context" do
      result =
        Markbridge.bbcode_to_markdown('[quote="alice, post:123, topic:456"]Quoted text[/quote]')
      expect(result.markdown).to eq("[quote=\"alice, post:123, topic:456\"]\nQuoted text\n[/quote]")
    end

    it "separates two consecutive plain quotes with a blank line" do
      result = Markbridge.bbcode_to_markdown("[quote]first[/quote][quote]second[/quote]")
      expect(result.markdown).to eq("> first\n\n> second")
    end

    it "separates two consecutive named quotes with a blank line" do
      result = Markbridge.bbcode_to_markdown("[quote=A]first[/quote][quote=B]second[/quote]")
      expect(result.markdown).to eq("[quote=\"A\"]\nfirst\n[/quote]\n\n[quote=\"B\"]\nsecond\n[/quote]")
    end

    it "separates a plain quote from trailing text with a blank line" do
      result = Markbridge.bbcode_to_markdown("[quote]quoted[/quote]after paragraph")
      expect(result.markdown).to eq("> quoted\n\nafter paragraph")
    end

    it "separates a named quote from trailing text with a blank line" do
      result = Markbridge.bbcode_to_markdown("[quote=A]quoted[/quote]after paragraph")
      expect(result.markdown).to eq("[quote=\"A\"]\nquoted\n[/quote]\n\nafter paragraph")
    end
  end

  describe "strikethrough" do
    it "converts strikethrough tags" do
      result = Markbridge.bbcode_to_markdown("[s]deleted text[/s]")
      expect(result.markdown).to eq("~~deleted text~~")
    end

    it "converts strike alias" do
      result = Markbridge.bbcode_to_markdown("[strike]deleted[/strike]")
      expect(result.markdown).to eq("~~deleted~~")
    end
  end

  describe "underline" do
    it "passes underline through as BBCode (Discourse renders [u] natively)" do
      result = Markbridge.bbcode_to_markdown("[u]underlined[/u]")
      expect(result.markdown).to eq("[u]underlined[/u]")
    end
  end

  describe "superscript and subscript" do
    it "converts superscript to HTML" do
      result = Markbridge.bbcode_to_markdown("[sup]2[/sup]")
      expect(result.markdown).to eq("<sup>2</sup>")
    end

    it "converts subscript to HTML" do
      result = Markbridge.bbcode_to_markdown("[sub]2[/sub]")
      expect(result.markdown).to eq("<sub>2</sub>")
    end

    it "handles superscript in context" do
      result = Markbridge.bbcode_to_markdown("x[sup]2[/sup] + y[sup]3[/sup]")
      expect(result.markdown).to eq("x<sup>2</sup> \\+ y<sup>3</sup>")
    end
  end

  describe "spoiler" do
    it "converts simple spoiler" do
      result = Markbridge.bbcode_to_markdown("[spoiler]secret content[/spoiler]")
      expect(result.markdown).to eq("[spoiler]secret content[/spoiler]")
    end

    it "converts spoiler with title" do
      result = Markbridge.bbcode_to_markdown("[spoiler=Click to reveal]secret[/spoiler]")
      expect(result.markdown).to eq("\\[spoiler=Click to reveal]secret\\[/spoiler]")
    end

    it "converts hide alias" do
      result = Markbridge.bbcode_to_markdown("[hide]hidden content[/hide]")
      expect(result.markdown).to eq("[spoiler]hidden content[/spoiler]")
    end
  end

  describe "email" do
    it "converts email with address option" do
      result = Markbridge.bbcode_to_markdown("[email=user@example.com]Contact us[/email]")
      expect(result.markdown).to eq("[Contact us](mailto:user@example.com)")
    end

    it "converts email with content as address" do
      result = Markbridge.bbcode_to_markdown("[email]user@example.com[/email]")
      expect(result.markdown).to eq("user@example.com")
    end
  end

  describe "alignment" do
    it "converts center alignment" do
      result = Markbridge.bbcode_to_markdown("[center]centered text[/center]")
      expect(result.markdown).to eq('<div align="center">centered text</div>')
    end

    it "converts right alignment" do
      result = Markbridge.bbcode_to_markdown("[right]right-aligned[/right]")
      expect(result.markdown).to eq('<div align="right">right-aligned</div>')
    end

    it "separates two consecutive aligned blocks with a blank line" do
      result = Markbridge.bbcode_to_markdown("[left]a[/left][right]b[/right]")
      expect(result.markdown).to eq(%(<div align="left">a</div>\n\n<div align="right">b</div>))
    end

    it "separates an aligned block from trailing text with a blank line" do
      result = Markbridge.bbcode_to_markdown("[center]a[/center]after")
      expect(result.markdown).to eq(%(<div align="center">a</div>\n\nafter))
    end
  end

  describe "block code separation" do
    it "separates two consecutive block code fences with a blank line" do
      result = Markbridge.bbcode_to_markdown("[code]line1\nline2[/code][code]line3\nline4[/code]")
      expect(result.markdown).to eq("```\nline1\nline2\n```\n\n```\nline3\nline4\n```")
    end

    it "separates a block code fence from trailing text with a blank line" do
      result = Markbridge.bbcode_to_markdown("[code]line1\nline2[/code]after")
      expect(result.markdown).to eq("```\nline1\nline2\n```\n\nafter")
    end
  end

  describe "edge cases" do
    it "drops unknown tag brackets but preserves content" do
      result = Markbridge.bbcode_to_markdown("[unknown]some text[/unknown]")
      expect(result.markdown).to eq("some text")
    end

    it "handles empty input" do
      result = Markbridge.bbcode_to_markdown("")
      expect(result.markdown).to eq("")
    end

    it "handles deeply nested formatting" do
      result = Markbridge.bbcode_to_markdown("[b][i][u]deep[/u][/i][/b]")
      expect(result.markdown).to eq("***[u]deep[/u]***")
    end

    it "handles unclosed tags gracefully" do
      result = Markbridge.bbcode_to_markdown("[b]bold text")
      expect(result.markdown).to eq("**bold text**")
    end

    it "inserts an HTML comment to break colliding emphasis delimiters between siblings" do
      # After reorder-with-reopen the Bold ends with *** and the reopened
      # Italic starts with * — adjacent they would form **** and parse
      # ambiguously in CommonMark.
      result =
        Markbridge.bbcode_to_markdown("[b]bold [i]italic [u]underline[/b] still here[/i][/u]")
      expect(result.markdown).to eq("**bold *italic [u]underline[/u]***<!---->*[u] still here[/u]*")
    end
  end

  describe "attachments" do
    it "converts attachment with numeric id (vBulletin/XenForo format)" do
      result = Markbridge.bbcode_to_markdown("[attach]1234[/attach]")
      expect(result.markdown).to eq("<!-- ATTACHMENT: id=1234 -->")
    end

    it "converts attachment with index and filename (phpBB format)" do
      result = Markbridge.bbcode_to_markdown("[attachment=0]image.jpg[/attachment]")
      expect(result.markdown).to eq("<!-- ATTACHMENT: index=0 filename=image.jpg -->")
    end

    it "converts attachment with index only (phpBB format)" do
      result = Markbridge.bbcode_to_markdown("[attachment=2][/attachment]")
      expect(result.markdown).to eq("<!-- ATTACHMENT: index=2 -->")
    end

    it "converts attachment with id and alt text (XenForo 2.1+ format)" do
      result = Markbridge.bbcode_to_markdown('[attach alt="diagram"]5678[/attach]')
      expect(result.markdown).to eq("<!-- ATTACHMENT: id=5678 alt=diagram -->")
    end

    it "converts self-closing attachment with SMF format" do
      result = Markbridge.bbcode_to_markdown("[attach id=2 msg=9876]")
      expect(result.markdown).to eq("<!-- ATTACHMENT: id=9876 index=2 -->")
    end

    it "converts attachment with filename only" do
      result = Markbridge.bbcode_to_markdown("[attach]document.pdf[/attach]")
      expect(result.markdown).to eq("<!-- ATTACHMENT: id=document.pdf -->")
    end

    it "handles attachment in context with text" do
      bbcode = "Check out this image: [attachment=0]screenshot.png[/attachment] for details."
      expected =
        "Check out this image: <!-- ATTACHMENT: index=0 filename=screenshot.png --> for details."

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result.markdown).to eq(expected)
    end

    it "handles multiple attachments" do
      bbcode = "[attach]111[/attach] and [attach]222[/attach]"
      expected = "<!-- ATTACHMENT: id=111 --> and <!-- ATTACHMENT: id=222 -->"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result.markdown).to eq(expected)
    end

    it "handles attachments in formatted text" do
      bbcode = "[b]Bold text with [attach]123[/attach] inside[/b]"
      expected = "**Bold text with <!-- ATTACHMENT: id=123 --> inside**"

      result = Markbridge.bbcode_to_markdown(bbcode)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "tables" do
    it "renders a simple table with headers as Markdown" do
      bbcode = "[table][tr][th]Name[/th][th]Age[/th][/tr][tr][td]Alice[/td][td]30[/td][/tr][/table]"

      result = Markbridge.bbcode_to_markdown(bbcode)

      expect(result.markdown).to eq("| Name | Age |\n| --- | --- |\n| Alice | 30 |")
    end

    it "renders a table without headers using first row as header" do
      bbcode = "[table][tr][td]A[/td][td]B[/td][/tr][tr][td]1[/td][td]2[/td][/tr][/table]"

      result = Markbridge.bbcode_to_markdown(bbcode)

      expect(result.markdown).to eq("| A | B |\n| --- | --- |\n| 1 | 2 |")
    end

    it "renders formatted content inside table cells" do
      bbcode = "[table][tr][th]Name[/th][/tr][tr][td][b]Alice[/b][/td][/tr][/table]"

      result = Markbridge.bbcode_to_markdown(bbcode)

      expect(result.markdown).to include("| **Alice** |")
    end

    it "falls back to HTML for uneven rows" do
      bbcode = "[table][tr][td]A[/td][td]B[/td][/tr][tr][td]1[/td][/tr][/table]"

      result = Markbridge.bbcode_to_markdown(bbcode)

      expect(result.markdown).to include("<table>")
      expect(result.markdown).to include("<td>A</td>")
    end
  end
end
