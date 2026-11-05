# frozen_string_literal: true

RSpec.describe "phpBB3 XML to Markdown" do
  describe "Markbridge.text_formatter_xml_to_markdown" do
    it "converts rich text with formatting and links" do
      xml = '<r>Hello <B>world</B>!<br/><URL url="https://example.com">example</URL></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("Hello **world**!\n[example](https://example.com)")
    end

    it "renders a name-only attribution for id-based quote attributes" do
      # post_id is a database id, not a Discourse post number — building a
      # "post:123, topic:456" reference from it would link the wrong post.
      # The ids stay on the AST (post_id/user_id) for consumers to remap.
      xml = '<r><QUOTE username="alice" post_id="123" topic_id="456">Quoted text</QUOTE></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("[quote=\"alice\"]\nQuoted text\n[/quote]")
    end

    it "renders ordered lists with proper spacing" do
      xml = '<r><LIST type="1"><LI>First</LI><LI>Second</LI></LIST></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("1. First\n1. Second")
    end

    it "renders multi-line code blocks with fences" do
      xml = "<r><CODE lang=\"ruby\">puts 'hello'\nputs 'world'</CODE></r>"

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("```ruby\nputs 'hello'\nputs 'world'\n```")
    end

    it "converts italic text" do
      result = Markbridge.text_formatter_xml_to_markdown("<r><I>italic</I></r>")
      expect(result.markdown).to eq("*italic*")
    end

    it "converts underline text" do
      result = Markbridge.text_formatter_xml_to_markdown("<r><U>underlined</U></r>")
      expect(result.markdown).to eq("[u]underlined[/u]")
    end

    it "converts strikethrough text" do
      result = Markbridge.text_formatter_xml_to_markdown("<r><S>deleted</S></r>")
      expect(result.markdown).to eq("~~deleted~~")
    end

    it "converts unordered lists" do
      xml = "<r><LIST><LI>One</LI><LI>Two</LI></LIST></r>"

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("- One\n- Two")
    end

    it "converts images" do
      xml = '<r><IMG src="https://example.com/photo.jpg"/></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("![](https://example.com/photo.jpg)")
    end

    it "converts email links" do
      xml = '<r><EMAIL email="user@example.com">Contact us</EMAIL></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("[Contact us](mailto:user@example.com)")
    end

    it "renders single-line CODE as a fenced block" do
      xml = "<r><CODE>var x = 1</CODE></r>"

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("```\nvar x = 1\n```")
    end

    it "converts nested formatting" do
      xml = "<r><B><I>bold italic</I></B></r>"

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("***bold italic***")
    end

    it "handles plain text without XML wrapper" do
      result = Markbridge.text_formatter_xml_to_markdown("Just plain text")
      expect(result.markdown).to eq("Just plain text")
    end

    it "handles empty input" do
      result = Markbridge.text_formatter_xml_to_markdown("")
      expect(result.markdown).to eq("")
    end

    it "converts spoiler tags" do
      xml = '<r><SPOILER title="Reveal">hidden content</SPOILER></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("Reveal: [spoiler]hidden content[/spoiler]")
    end

    it "converts color tags into their text" do
      xml = '<r><COLOR color="red">red text</COLOR></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("red text")
    end

    it "converts size tags into their text" do
      xml = '<r><SIZE size="20">big text</SIZE></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("big text")
    end

    it "converts color and size tags into BBCode with the bbcode feature" do
      xml =
        '<r><COLOR color="#FF0000">red</COLOR> <SIZE size="85"><s>[size=85]</s>small<e>[/size]</e></SIZE></r>'
      renderer = Markbridge.discourse_renderer(features: { bbcode: true })

      result = Markbridge.text_formatter_xml_to_markdown(xml, renderer:)

      expect(result.markdown).to eq("[color=#FF0000]red[/color] [size=85]small[/size]")
    end

    it "closes and reopens color around a blank line with the bbcode feature" do
      xml = "<r><COLOR color=\"red\">a<br/>\n<br/>\nb</COLOR></r>"
      renderer = Markbridge.discourse_renderer(features: { bbcode: true })

      result = Markbridge.text_formatter_xml_to_markdown(xml, renderer:)

      expect(result.markdown).to eq("[color=red]a[/color]\n\n[color=red]b[/color]")
    end
  end

  describe "phpBB 3.x posts" do
    def convert(xml)
      Markbridge.text_formatter_xml_to_markdown(xml).markdown
    end

    it "keeps the space between two inline elements" do
      xml = "<r><B><s>[b]</s>a<e>[/b]</e></B> <I><s>[i]</s>b<e>[/i]</e></I></r>"

      expect(convert(xml)).to eq("**a** *b*")
    end

    it "converts an attachment with its fallback filename" do
      xml =
        '<r><ATTACHMENT filename="a.png" index="0"><s>[attachment=0]</s>a.png<e>[/attachment]</e></ATTACHMENT></r>'

      expect(convert(xml)).to eq("<!-- ATTACHMENT: index=0 filename=a.png -->")
    end

    it "converts an image with its fallback URL" do
      xml =
        '<r><IMG src="https://example.com/a.png"><s>[img]</s>https://example.com/a.png<e>[/img]</e></IMG></r>'

      expect(convert(xml)).to eq("![](https://example.com/a.png)")
    end

    # [u] is the only output that puts a BBCode tag right inside the
    # emphasis markers. "[" is punctuation, so ** between a letter and "["
    # can't open without the boundary comment.
    it "keeps bold that starts with underline after a letter working" do
      xml = "<r>a<B><s>[b]</s><U><s>[u]</s>b<e>[/u]</e></U> c<e>[/b]</e></B>d</r>"

      expect(convert(xml)).to eq("a<!---->**[u]b[/u] c**d")
    end

    it "keeps bold that only holds underline between two letters working" do
      xml = "<r>x<B><s>[b]</s><U><s>[u]</s>b<e>[/u]</e></U><e>[/b]</e></B>y</r>"

      expect(convert(xml)).to eq("x<!---->**[u]b[/u]**<!---->y")
    end

    it "converts bold and underline that overlap in the source" do
      xml = "<r>a <B><s>[b]</s>b <U><s>[u]</s>c<e>[/b]</e></U></B><U> d<e>[/u]</e></U> e</r>"

      expect(convert(xml)).to eq("a **b [u]c[/u]**[u] d[/u] e")
    end

    it "skips text that s9e ignored" do
      expect(convert("<r>x<i>[/b]</i> y</r>")).to eq("x y")
    end

    it "converts a line break into a single newline" do
      expect(convert("<t>a<br/>\nb</t>")).to eq("a\nb")
    end

    it "converts two line breaks into a blank line" do
      expect(convert("<t>a<br/>\n<br/>\nb</t>")).to eq("a\n\nb")
    end

    it "keeps bold across a line break" do
      expect(convert("<r><B><s>[b]</s>a<br/>\nb<e>[/b]</e></B></r>")).to eq("**a\nb**")
    end

    it "keeps the lines of a quote together" do
      xml =
        "<r><QUOTE><s>[quote]</s>a <B><s>[b]</s>b<e>[/b]</e></B> c<br/>\nd<e>[/quote]</e></QUOTE></r>"

      expect(convert(xml)).to eq("> a **b** c\n> d")
    end

    it "escapes lines that look like Markdown without blank lines between them" do
      xml = "<t>1. first<br/>\n* star<br/>\n___<br/>\n~~~~</t>"

      expect(convert(xml)).to eq("1\\. first\n\\* star\n\\_\\_\\_\n\\~\\~\\~\\~")
    end

    it "keeps newlines and indentation in code" do
      xml = "<r><CODE><s>[code]</s>line1\n    line2<e>[/code]</e></CODE></r>"

      expect(convert(xml)).to eq("```\nline1\n    line2\n```")
    end

    it "converts a quote without author around a quote with author into [quote]" do
      xml =
        '<r><QUOTE><s>[quote]</s><QUOTE author="X"><s>[quote="X"]</s>in<e>[/quote]</e></QUOTE><e>[/quote]</e></QUOTE>reply</r>'

      expect(convert(xml)).to eq("[quote]\n[quote=\"X\"]\nin\n[/quote]\n[/quote]\n\nreply")
    end

    it "converts an empty quote without author into nothing" do
      expect(convert("<r>x<QUOTE><s>[quote]</s><e>[/quote]</e></QUOTE>y</r>")).to eq("xy")
    end

    it "removes the indentation at the start of a line" do
      expect(convert("<t>a<br/>\n          b</t>")).to eq("a\nb")
    end

    it "closes and reopens bold around a blank line" do
      xml = "<r><B><s>[b]</s>a<br/>\n<br/>\nb<e>[/b]</e></B> c</r>"

      expect(convert(xml)).to eq("**a**\n\n**b** c")
    end

    it "closes bold before a blank line at its end" do
      xml = "<r><B><s>[b]</s>a<br/>\n<br/>\n<e>[/b]</e></B>b</r>"

      expect(convert(xml)).to eq("**a**\n\nb")
    end

    it "closes and reopens italic, strikethrough and underline around a blank line" do
      expect(convert("<r><I>a<br/>\n<br/>\nb</I></r>")).to eq("*a*\n\n*b*")
      expect(convert("<r><S>a<br/>\n<br/>\nb</S></r>")).to eq("~~a~~\n\n~~b~~")
      expect(convert("<r><U>a<br/>\n<br/>\nb</U></r>")).to eq("[u]a[/u]\n\n[u]b[/u]")
    end

    it "closes and reopens nested formatting around a blank line" do
      xml = "<r><B><s>[b]</s><I><s>[i]</s>a<br/><br/>b<e>[/i]</e></I><e>[/b]</e></B></r>"

      expect(convert(xml)).to eq("***a***\n\n***b***")
    end

    it "closes and reopens bold around a blank line in a list item" do
      xml = "<r><LIST><LI><s>[*]</s><B>a<br/>\n<br/>\nb</B></LI></LIST></r>"

      expect(convert(xml)).to eq("- **a**\n\n  **b**")
    end

    it "closes and reopens bold around a blank line in a quote" do
      xml = "<r><QUOTE author=\"alice\"><B>a<br/>\n<br/>\nb</B></QUOTE></r>"

      expect(convert(xml)).to eq("[quote=\"alice\"]\n**a**\n\n**b**\n[/quote]")
    end

    it "removes the indentation inside an inline element at the start of a line" do
      xml = "<r>a<br/>\n<B><s>[b]</s>          b<e>[/b]</e></B></r>"

      expect(convert(xml)).to eq("a\n**b**")
    end
  end

  describe "tables" do
    it "renders a table as Markdown" do
      xml =
        "<r><TABLE><TR><TH>Name</TH><TH>Age</TH></TR><TR><TD>Alice</TD><TD>30</TD></TR></TABLE></r>"

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("| Name | Age |\n| --- | --- |\n| Alice | 30 |")
    end

    it "falls back to HTML for uneven rows" do
      xml = "<r><TABLE><TR><TD>A</TD><TD>B</TD></TR><TR><TD>1</TD></TR></TABLE></r>"

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to include("<table>")
    end
  end
end
