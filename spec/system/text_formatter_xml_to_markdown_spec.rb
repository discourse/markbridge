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

    it "converts inline code" do
      xml = "<r><CODE>var x = 1</CODE></r>"

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("`var x = 1`")
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

      expect(result.markdown).to eq("[spoiler=Reveal]hidden content[/spoiler]")
    end

    it "converts color tags" do
      xml = '<r><COLOR color="red">red text</COLOR></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq('<span style="color: red">red text</span>')
    end

    it "converts size tags" do
      xml = '<r><SIZE size="20">big text</SIZE></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq('<span style="font-size: 20px">big text</span>')
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
