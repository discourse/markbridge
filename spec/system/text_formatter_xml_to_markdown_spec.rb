# frozen_string_literal: true

RSpec.describe "phpBB3 XML to Markdown" do
  describe "Markbridge.text_formatter_xml_to_markdown" do
    it "converts rich text with formatting and links" do
      xml = '<r>Hello <B>world</B>!<br/><URL url="https://example.com">example</URL></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result).to eq("Hello **world**!\n[example](https://example.com)")
    end

    it "renders Discourse quote markup when attribution is present" do
      xml = '<r><QUOTE username="alice" post_id="123" topic_id="456">Quoted text</QUOTE></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result).to eq("[quote=\"alice, post:123, topic:456\"]\nQuoted text\n[/quote]")
    end

    it "renders ordered lists with proper spacing" do
      xml = '<r><LIST type="1"><LI>First</LI><LI>Second</LI></LIST></r>'

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result).to eq("1. First\n1. Second")
    end

    it "renders multi-line code blocks with fences" do
      xml = "<r><CODE lang=\"ruby\">puts 'hello'\nputs 'world'</CODE></r>"

      result = Markbridge.text_formatter_xml_to_markdown(xml)

      expect(result).to eq("```ruby\nputs 'hello'\nputs 'world'\n```")
    end
  end
end
