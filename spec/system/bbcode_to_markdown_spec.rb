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

    describe "nested list indentation" do
      it "indents a continuation line to the content column of its own item" do
        result = Markbridge.bbcode_to_markdown("[list][*]a[list][*]b[br]more[/list][/list]")

        expect(result.markdown).to eq("- a\n  - b\n    more")
      end

      it "keeps the continuation line at the content column three levels down" do
        result =
          Markbridge.bbcode_to_markdown(
            "[list][*]a[list][*]b[list][*]c[br]more[/list][/list][/list]",
          )

        expect(result.markdown).to eq("- a\n  - b\n    - c\n      more")
      end

      it "gives an ordered item three spaces of continuation indentation" do
        result = Markbridge.bbcode_to_markdown("[list=1][*]a[br]more[/list]")

        expect(result.markdown).to eq("1. a\n   more")
      end

      it "indents a quote inside a nested item as one unit" do
        result =
          Markbridge.bbcode_to_markdown("[list][*]a[list][*]b[quote]q1\nq2[/quote][/list][/list]")

        expect(result.markdown).to eq("- a\n  - b\n\n    > q1\n    > q2")
      end

      it "keeps a code block inside its item when ordered and unordered lists alternate" do
        result =
          Markbridge.bbcode_to_markdown(
            "[list=1][*]a[list][*]b[list=1][*]c[code]x\ny[/code][/list][/list][/list]",
          )

        expect(result.markdown).to eq(
          "1. a\n   - b\n     1. c\n\n        ```\n        x\n        y\n        ```",
        )
      end

      it "keeps the boundary comment between two emphasis siblings in a list item" do
        result = Markbridge.bbcode_to_markdown("[list][*][b]a[/b][i]b[/i][/list]")

        expect(result.markdown).to eq("- **a**<!---->*b*")
      end

      it "drops a blank line the source put in front of a nested list" do
        result = Markbridge.bbcode_to_markdown("[list][*]parent\n\n[list][*]a[/list][/list]")

        expect(result.markdown).to eq("- parent\n  - a")
      end

      it "keeps the blank line after an HTML table in front of a nested list" do
        result =
          Markbridge.bbcode_to_markdown(
            "[list][*]item[table][tr][td]a[/td][/tr][tr][td]b[/td][td]c[/td][/tr][/table]" \
              "[list][*]x[/list][/list]",
          )

        expect(result.markdown).to eq(
          "- item\n\n  <table>\n  <tr><td>a</td></tr>\n  <tr><td>b</td><td>c</td></tr>\n" \
            "  </table>\n\n  - x",
        )
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
          - ```
            Code item
            ```
        MARKDOWN

        result = Markbridge.bbcode_to_markdown(bbcode)
        expect(result.markdown).to eq(expected)
      end

      it "keeps content after a nested code block inside its list item" do
        result =
          Markbridge.bbcode_to_markdown(
            "[list][*]outer[list][*][code]  x[/code][/list]after[/list]",
          )

        expect(result.markdown).to eq("- outer\n  - ```\n      x\n    ```\n\n  after")
      end

      it "keeps text after a nested list in the outer item" do
        result = Markbridge.bbcode_to_markdown("[list][*]a[list=1][*]b[/list]c[/list]")

        expect(result.markdown).to eq("- a\n  1. b\n\n  c")
      end

      it "keeps text after a list inside a quote inside an item out of the last list item" do
        result = Markbridge.bbcode_to_markdown("[list][*]a[quote][list][*]b[/list]c[/quote][/list]")

        expect(result.markdown).to eq("- a\n\n  > \n  > \n  > - b\n  > \n  > \n  > c")
      end

      it "preserves indentation when code is the item's only content" do
        result = Markbridge.bbcode_to_markdown("[list][*][code]  x[/code][/list]")

        expect(result.markdown).to eq("- ```\n    x\n  ```")
      end

      # CodeTag switches to a tilde wrapper because the code has backticks.
      it "preserves indentation in code that contains a backtick fence" do
        result =
          Markbridge.bbcode_to_markdown("[list][*]parent[code]```ruby\n  x\n```[/code][/list]")

        expect(result.markdown).to eq("- parent\n\n  ~~~\n  ```ruby\n    x\n  ```\n  ~~~")
      end

      it "preserves indentation inside code nested in a list item" do
        result =
          Markbridge.bbcode_to_markdown("[list][*]parent[code]def f\n  return 1\nend[/code][/list]")

        expect(result.markdown).to eq("- parent\n\n  ```\n  def f\n    return 1\n  end\n  ```")
      end

      it "keeps a code fence at its item's content column when deeply nested" do
        result =
          Markbridge.bbcode_to_markdown(
            "[list][*]a[list][*]b[list][*]c[code]x[/code][/list][/list][/list]",
          )

        expect(result.markdown).to eq("- a\n  - b\n    - c\n\n      ```\n      x\n      ```")
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

        # The nested [code] renders as a fence inside the nested list item;
        # the line before it keeps its trailing space from the source.
        expected =
          "- Item with **bold** and *italic*\n" \
            "  - Nested with \n\n    ```\n    code\n    ```"

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

    it "converts code tags to fenced blocks even for single-line content" do
      result = Markbridge.bbcode_to_markdown("[code]code text[/code]")
      expect(result.markdown).to eq("```\ncode text\n```")
    end

    it "keeps tt tags inline" do
      result = Markbridge.bbcode_to_markdown("[tt]code text[/tt]")
      expect(result.markdown).to eq("`code text`")
    end

    it "renders empty code tags to nothing" do
      result = Markbridge.bbcode_to_markdown("a [code][/code] b")
      expect(result.markdown).to eq("a  b")
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

    it "separates two lists of the same kind" do
      result = Markbridge.bbcode_to_markdown("[list][*]a[/list][list][*]b[/list]")
      expect(result.markdown).to eq("- a\n\n<!---->\n\n- b")
    end

    it "does not separate an unordered list from an ordered one" do
      result = Markbridge.bbcode_to_markdown("[list][*]a[/list][list=1][*]b[/list]")
      expect(result.markdown).to eq("- a\n\n1. b")
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
          "Plain text with [b]bold[/b] and [i]italic[/i] and [tt]code[/tt].",
        )
      expect(result.markdown).to eq("Plain text with **bold** and *italic* and `code`.")
    end

    it "renders a mid-sentence code tag as a fence with blank lines around it" do
      result =
        Markbridge.bbcode_to_markdown(
          "Plain text with [b]bold[/b] and [i]italic[/i] and [code]code[/code].",
        )
      expect(result.markdown).to eq(
        "Plain text with **bold** and *italic* and \n\n```\ncode\n```\n\n.",
      )
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

  describe "emphasis next to a word" do
    it "keeps emphasis that starts with punctuation working after a word" do
      result = Markbridge.bbcode_to_markdown("item[i]#[/i]")
      expect(result.markdown).to eq("item<!---->*\\#*")
    end

    it "keeps emphasis that ends with punctuation working in front of a word" do
      result = Markbridge.bbcode_to_markdown("[b]*bold*[/b]tail")
      expect(result.markdown).to eq("**\\*bold\\***<!---->tail")
    end
  end

  describe "text next to a link" do
    it "keeps a ! in front of a link from turning it into an image" do
      result = Markbridge.bbcode_to_markdown("Look![url=https://example.com]here[/url]")
      expect(result.markdown).to eq("Look\\![here](https://example.com)")
    end
  end

  describe "horizontal rules" do
    it "keeps a rule that starts a list item inside the list" do
      result = Markbridge.bbcode_to_markdown("[list][*]Foo[*][hr][*]Bar[/list]")
      expect(result.markdown).to eq("- Foo\n- * * *\n- Bar")
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

    it "writes a bare url glued to text as an autolink" do
      result = Markbridge.bbcode_to_markdown("a[url=https://example.com]https://example.com[/url]b")
      expect(result.markdown).to eq("a<https://example.com>b")
    end

    it "keeps a bare url between spaces plain" do
      result =
        Markbridge.bbcode_to_markdown("see [url=https://example.com]https://example.com[/url] now")
      expect(result.markdown).to eq("see https://example.com now")
    end

    it "converts url with formatted content" do
      result = Markbridge.bbcode_to_markdown("[url=https://example.com][b]Bold link[/b][/url]")
      expect(result.markdown).to eq("[**Bold link**](https://example.com)")
    end

    it "drops [u] wrapper inside link text since Discourse does not re-cook BBCode there" do
      result = Markbridge.bbcode_to_markdown("[url=https://example.com][u]Facebook[/u][/url]")
      expect(result.markdown).to eq("[Facebook](https://example.com)")
    end

    it "drops [u] wrapper transitively when nested inside other inline formatting in a link" do
      result =
        Markbridge.bbcode_to_markdown("[url=https://example.com][b][u]Facebook[/u][/b][/url]")
      expect(result.markdown).to eq("[**Facebook**](https://example.com)")
    end
  end

  describe "images" do
    it "converts simple image" do
      result = Markbridge.bbcode_to_markdown("[img]https://example.com/photo.jpg[/img]")
      expect(result.markdown).to eq("![](https://example.com/photo.jpg)")
    end

    it "converts image with alternative text" do
      result =
        Markbridge.bbcode_to_markdown(
          "[img alt=\"a cat\" width=100]https://example.com/photo.jpg[/img]",
        )
      expect(result.markdown).to eq("![a cat|100](https://example.com/photo.jpg)")
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
      expect(result.markdown).to eq(
        "[quote=\"A\"]\nfirst\n[/quote]\n\n[quote=\"B\"]\nsecond\n[/quote]",
      )
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

    it "drops [u] wrapper inside email link text" do
      result = Markbridge.bbcode_to_markdown("[email=user@example.com][u]Contact[/u][/email]")
      expect(result.markdown).to eq("[Contact](mailto:user@example.com)")
    end
  end

  describe "alignment" do
    it "converts center alignment" do
      result = Markbridge.bbcode_to_markdown("[center]centered text[/center]")
      expect(result.markdown).to eq(%(<div align="center">\n\ncentered text\n\n</div>))
    end

    it "converts right alignment" do
      result = Markbridge.bbcode_to_markdown("[right]right-aligned[/right]")
      expect(result.markdown).to eq(%(<div align="right">\n\nright-aligned\n\n</div>))
    end

    it "parses a link inside an aligned block as Markdown" do
      result =
        Markbridge.bbcode_to_markdown("[center][url=https://example.com]a link[/url][/center]")
      expect(result.markdown).to eq(
        %(<div align="center">\n\n[a link](https://example.com)\n\n</div>),
      )
    end

    it "keeps one blank line per side around content that brackets itself" do
      result = Markbridge.bbcode_to_markdown("[center][list][*]a[*]b[/list][/center]")
      expect(result.markdown).to eq(%(<div align="center">\n\n- a\n- b\n\n</div>))
    end

    it "keeps a nested list's items indented and its island boundary intact" do
      result =
        Markbridge.bbcode_to_markdown(
          "[list][*]parent[center][list][*]a[*]b[/list][/center][/list]",
        )
      expect(result.markdown).to eq(
        %(- parent\n\n  <div align="center">\n\n  - a\n  - b\n\n  </div>),
      )
    end

    it "keeps that shape when the source supplies its own blank lines" do
      result =
        Markbridge.bbcode_to_markdown(
          "[list][*]parent[center]\n\n[list][*]a[*]b[/list][/center][/list]",
        )
      expect(result.markdown).to eq(
        %(- parent\n\n  <div align="center">\n\n  - a\n  - b\n\n  </div>),
      )
    end

    it "parses a link inside an aligned block nested in a list item" do
      result =
        Markbridge.bbcode_to_markdown(
          "[list][*]parent[center][url=https://example.com]a link[/url][/center][/list]",
        )
      expect(result.markdown).to eq(
        %(- parent\n\n  <div align="center">\n\n  [a link](https://example.com)\n\n  </div>),
      )
    end

    it "keeps the closing div aligned with its list at two levels of nesting" do
      result =
        Markbridge.bbcode_to_markdown(
          "[list][*]outer[list][*]parent[center][list][*]a[*]b[/list][/center]" \
            "[list][*]c[/list][/list][/list]",
        )
      expect(result.markdown).to eq(
        "- outer\n  - parent\n\n    <div align=\"center\">\n\n    - a\n    - b\n\n" \
          "    </div>\n\n    - c",
      )
    end

    it "separates two consecutive aligned blocks with a blank line" do
      result = Markbridge.bbcode_to_markdown("[left]a[/left][right]b[/right]")
      expect(result.markdown).to eq(
        %(<div align="left">\n\na\n\n</div>\n\n<div align="right">\n\nb\n\n</div>),
      )
    end

    it "separates an aligned block from trailing text with a blank line" do
      result = Markbridge.bbcode_to_markdown("[center]a[/center]after")
      expect(result.markdown).to eq(%(<div align="center">\n\na\n\n</div>\n\nafter))
    end

    it "keeps the aligned div tight inside an HTML table" do
      result =
        Markbridge.bbcode_to_markdown(
          "[table][tr][td][center][b]c[/b][/center][/td][/tr][tr][td]x[/td][td]y[/td][/tr][/table]",
        )
      expect(result.markdown).to include(%(<td><div align="center"><strong>c</strong></div></td>))
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

    # The `=` line starts its own text node, so the escaper cannot see the
    # paragraph line that the inline markup produced before it. Without the
    # escape, Discourse cooks both lines as an <h1>.
    it "escapes a =-only line after a bold tag" do
      result = Markbridge.bbcode_to_markdown("[b]Body[/b]\n===")
      expect(result.markdown).to eq("**Body**\n\\=\\=\\=")
    end

    it "escapes a =-only line after text with inline markup" do
      result = Markbridge.bbcode_to_markdown("Body [i]x[/i]\n===")
      expect(result.markdown).to eq("Body *x*\n\\=\\=\\=")
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
