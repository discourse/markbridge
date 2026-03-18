# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "Discourse ndash/mdash conversion" do
    # Discourse converts -- to &ndash; and --- to &mdash;
    # We must escape each dash to prevent partial conversion like \-&ndash;

    it "escapes -- to prevent ndash conversion" do
      expect(escaper.escape("--")).to eq("\\-\\-")
    end

    it "escapes --- to prevent mdash conversion" do
      expect(escaper.escape("---")).to eq("\\-\\-\\-")
    end

    it "escapes -- in prose" do
      input = "foo -- bar"
      result = escaper.escape(input)
      expect(result).to eq("foo \\-\\- bar")
    end

    it "escapes --- in prose" do
      input = "foo --- bar"
      result = escaper.escape(input)
      expect(result).to eq("foo \\-\\-\\- bar")
    end

    it "escapes multiple dashes in sequence" do
      input = "----"
      result = escaper.escape(input)
      expect(result).to eq("\\-\\-\\-\\-")
    end

    it "escapes dashes at end of sentence" do
      input = "Wait--"
      result = escaper.escape(input)
      expect(result).to eq("Wait\\-\\-")
    end

    it "escapes em-dash style ---" do
      input = "He said---and I quote---nothing."
      result = escaper.escape(input)
      expect(result).to eq("He said\\-\\-\\-and I quote\\-\\-\\-nothing.")
    end
  end
end
