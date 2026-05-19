# frozen_string_literal: true

RSpec.describe "HTML to Markdown Conversion" do
  describe "simple formatting" do
    it "converts bold text" do
      html = "<b>bold text</b>"
      expected = "**bold text**"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts italic text" do
      html = "<i>italic text</i>"
      expected = "*italic text*"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts strikethrough text" do
      html = "<s>deleted text</s>"
      expected = "~~deleted text~~"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts nested formatting" do
      html = "<b><i>bold italic</i></b>"
      expected = "***bold italic***"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "links" do
    it "converts simple link" do
      html = '<a href="https://example.com">Click here</a>'
      expected = "[Click here](https://example.com)"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts link with no text" do
      html = '<a href="https://example.com"></a>'
      expected = "[](https://example.com)"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "images" do
    it "converts image" do
      html = '<img src="https://example.com/photo.jpg">'
      expected = "![](https://example.com/photo.jpg)"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts image with dimensions" do
      html = '<img src="photo.jpg" width="100" height="200">'
      expected = "![|100x200](photo.jpg)"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "lists" do
    it "converts unordered list" do
      html = <<~HTML
        <ul>
        <li>Item 1</li>
        <li>Item 2</li>
        <li>Item 3</li>
        </ul>
      HTML

      expected = <<~MARKDOWN.strip
        - Item 1
        - Item 2
        - Item 3
      MARKDOWN

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts ordered list" do
      html = <<~HTML
        <ol>
        <li>First</li>
        <li>Second</li>
        <li>Third</li>
        </ol>
      HTML

      expected = <<~MARKDOWN.strip
        1. First
        1. Second
        1. Third
      MARKDOWN

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts nested lists" do
      html = <<~HTML
        <ul>
        <li>Item 1</li>
        <li>Item 2
        <ul>
        <li>Subitem 2.1</li>
        <li>Subitem 2.2</li>
        </ul>
        </li>
        <li>Item 3</li>
        </ul>
      HTML

      expected = <<~MARKDOWN.strip
        - Item 1
        - Item 2
          - Subitem 2.1
          - Subitem 2.2
        - Item 3
      MARKDOWN

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "code" do
    it "converts inline code" do
      html = "<code>var x = 1;</code>"
      expected = "`var x = 1;`"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts code block" do
      html = "<pre>function hello() {\n  console.log('hi');\n}</pre>"
      expected = "```\nfunction hello() {\n  console.log('hi');\n}\n```"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "blockquote" do
    it "converts simple blockquote" do
      html = "<blockquote>Quoted text</blockquote>"
      expected = "> Quoted text"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "treats raw newlines in blockquote source as whitespace per HTML spec" do
      # Per HTML spec, newlines in source HTML are whitespace, not paragraph
      # breaks. Authors who want paragraphs must use <p> (or <br> for breaks).
      html = "<blockquote>First paragraph\n\nSecond paragraph</blockquote>"
      expected = "> First paragraph Second paragraph"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "line breaks and horizontal rules" do
    it "converts line break" do
      html = "Line 1<br>Line 2"
      expected = "Line 1\nLine 2"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts horizontal rule" do
      html = "Text<hr>More text"
      expected = "Text\n\n---\n\nMore text"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "whitespace collapsing per HTML spec" do
    it "drops a leading newline before nested content inside a link" do
      html = %(<a href="https://twitter.com/lamresearch">\n<u>Twitter</u></a>)
      expected = "[Twitter](https://twitter.com/lamresearch)"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "drops a trailing newline after nested content inside a link" do
      html = %(<a href="https://example.com"><u>Twitter</u>\n</a>)
      expected = "[Twitter](https://example.com)"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "collapses runs of whitespace within text to a single space" do
      html = "<p>Click   <a href=\"https://example.com\">here\nfor\tinfo</a> now</p>"
      expected = "Click [here for info](https://example.com) now"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "preserves whitespace inside <pre>" do
      html = "<pre>line1\nline2\n  indented</pre>"
      expected = "```\nline1\nline2\n  indented\n```"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "preserves whitespace inside inline <code>" do
      html = "<code>fn  call</code>"
      expected = "`fn  call`"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "drops trailing whitespace before a block-level <hr>" do
      html = "foo  \n<hr>bar"
      expected = "foo\n\n---\n\nbar"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "block element boundaries" do
    it "separates raw text from a following <p> with a blank line" do
      html = "some loose text<p>real paragraph</p>"
      expected = "some loose text\n\nreal paragraph"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "separates raw text from a following <blockquote> with a blank line" do
      html = "intro<blockquote>quoted</blockquote>"
      expected = "intro\n\n> quoted"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "separates raw text from a following <pre> block with a blank line" do
      html = "intro<pre>code\nblock</pre>"
      expected = "intro\n\n```\ncode\nblock\n```"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "still separates consecutive paragraphs cleanly" do
      html = "<p>first</p><p>second</p>"
      expected = "first\n\nsecond"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "still nests lists tightly" do
      # Block-element boundary handling must not loosen tight nested lists.
      html = "<ul><li>parent<ul><li>child</li></ul></li></ul>"
      expected = "- parent\n  - child"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "trailing invisible characters with strip_trailing_invisibles" do
    let(:renderer) { Markbridge.discourse_renderer(strip_trailing_invisibles: true) }

    it "strips trailing zero-width space at the end of a paragraph" do
      html = "<p>Hello Specialist&#8203;</p><p>Our customer are unhappy</p>"

      result = Markbridge.html_to_markdown(html, renderer:)
      expect(result.markdown).to eq("Hello Specialist\n\nOur customer are unhappy")
    end

    it "drops an Outlook-style nbsp-only spacer paragraph between content" do
      html = '<p>before</p><p class="MsoNormal">&nbsp;</p><p>after</p>'

      result = Markbridge.html_to_markdown(html, renderer:)
      expect(result.markdown).to eq("before\n\nafter")
    end

    it "preserves leading nbsp (author intent — used as indentation)" do
      html = "<p>&nbsp;Hello</p>"

      result = Markbridge.html_to_markdown(html, renderer:)
      expect(result.markdown).to eq(" Hello")
    end

    it "preserves invisibles in the middle of content" do
      # Mid-content ZWSP is a meaningful soft-break hint (long URLs, CJK),
      # only line-end invisibles get stripped.
      html = "<p>before​inline​text</p>"

      result = Markbridge.html_to_markdown(html, renderer:)
      expect(result.markdown).to eq("before​inline​text")
    end
  end

  describe "complex combinations" do
    it "converts mixed content" do
      html = <<~HTML
        <p>This is <b>bold</b> and <i>italic</i> text.</p>
        <ul>
        <li>Item with <a href="https://example.com">link</a></li>
        <li>Item with <code>code</code></li>
        </ul>
      HTML

      expected = <<~MARKDOWN.strip
        This is **bold** and *italic* text.

        - Item with [link](https://example.com)
        - Item with `code`
      MARKDOWN

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "underline" do
    it "converts underline to [u] BBCode" do
      result = Markbridge.html_to_markdown("<u>underlined text</u>")
      expect(result.markdown).to eq("[u]underlined text[/u]")
    end
  end

  describe "superscript and subscript" do
    it "converts superscript" do
      result = Markbridge.html_to_markdown("<sup>2</sup>")
      expect(result.markdown).to eq("<sup>2</sup>")
    end

    it "converts subscript" do
      result = Markbridge.html_to_markdown("<sub>2</sub>")
      expect(result.markdown).to eq("<sub>2</sub>")
    end

    it "handles inline superscript" do
      result = Markbridge.html_to_markdown("x<sup>2</sup> + y<sup>3</sup>")
      expect(result.markdown).to eq("x<sup>2</sup> \\+ y<sup>3</sup>")
    end
  end

  describe "edge cases" do
    it "handles empty input" do
      result = Markbridge.html_to_markdown("")
      expect(result.markdown).to eq("")
    end

    it "preserves plain text" do
      result = Markbridge.html_to_markdown("Just plain text")
      expect(result.markdown).to eq("Just plain text")
    end

    it "handles deeply nested formatting" do
      result = Markbridge.html_to_markdown("<b><i><u>deep</u></i></b>")
      expect(result.markdown).to eq("***[u]deep[/u]***")
    end
  end

  describe "strong and em tags" do
    it "converts strong to bold" do
      html = "<strong>strong text</strong>"
      expected = "**strong text**"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "converts em to italic" do
      html = "<em>emphasized text</em>"
      expected = "*emphasized text*"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "paragraphs" do
    it "separates adjacent paragraphs with blank lines" do
      html = "<p>One</p><p>Two</p>"
      expected = "One\n\nTwo"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "handles multiple paragraphs" do
      html = "<p>First</p><p>Second</p><p>Third</p>"
      expected = "First\n\nSecond\n\nThird"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "handles paragraphs from minified HTML without whitespace" do
      html = "<p>Paragraph one</p><p>Paragraph two</p>"
      expected = "Paragraph one\n\nParagraph two"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end

    it "handles paragraphs with formatted content" do
      html = "<p><b>Bold</b> text</p><p><i>Italic</i> text</p>"
      expected = "**Bold** text\n\n*Italic* text"

      result = Markbridge.html_to_markdown(html)
      expect(result.markdown).to eq(expected)
    end
  end

  describe "tables" do
    it "renders a simple HTML table as Markdown" do
      html = "<table><tr><th>Name</th><th>Age</th></tr><tr><td>Alice</td><td>30</td></tr></table>"

      result = Markbridge.html_to_markdown(html)

      expect(result.markdown).to eq("| Name | Age |\n| --- | --- |\n| Alice | 30 |")
    end

    it "handles thead and tbody" do
      html =
        "<table><thead><tr><th>A</th><th>B</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>"

      result = Markbridge.html_to_markdown(html)

      expect(result.markdown).to eq("| A | B |\n| --- | --- |\n| 1 | 2 |")
    end

    it "falls back to HTML for uneven rows" do
      html = "<table><tr><td>A</td><td>B</td></tr><tr><td>1</td></tr></table>"

      result = Markbridge.html_to_markdown(html)

      expect(result.markdown).to include("<table>")
    end

    it "drops the spurious <p> wrapper when a single paragraph fills a cell" do
      # Newline content forces the html_mode fallback. The cell contains
      # one <p>; the surrounding <td> already provides block context, so
      # the <p> wrapper would just add vertical margin and (in the
      # block-content case) would emit invalid HTML5.
      html = "<table><tr><td><p>line one<br>line two</p></td></tr></table>"

      result = Markbridge.html_to_markdown(html)

      expect(result.markdown).to include("<td>line one<br>line two</td>")
      expect(result.markdown).not_to include("<td><p>")
    end
  end
end
