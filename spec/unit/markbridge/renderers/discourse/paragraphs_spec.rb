# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Paragraphs do
  def wrap(content)
    described_class.map(content) { |paragraph| "<#{paragraph}>" }
  end

  describe ".map" do
    it "yields content without a blank line as a whole" do
      expect(wrap("a\nb")).to eq("<a\nb>")
    end

    it "yields every paragraph on its own and keeps the blank line" do
      expect(wrap("a\n\nb\n\nc")).to eq("<a>\n\n<b>\n\n<c>")
    end

    it "treats a line of spaces or tabs as a blank line" do
      expect(wrap("a\n \t\nb")).to eq("<a>\n \t\n<b>")
    end

    it "keeps a run of blank lines together" do
      expect(wrap("a\n\n \n\nb")).to eq("<a>\n\n \n\n<b>")
    end

    it "yields the empty text before a leading blank line and nothing after a trailing one" do
      expect(wrap("\n\na\n\n")).to eq("<>\n\n<a>\n\n")
    end

    it "yields content with a code fence as a whole" do
      expect(wrap("a\n\n```\nx\n\ny\n```")).to eq("<a\n\n```\nx\n\ny\n```>")
      expect(wrap("a\n\n~~~\nx\n\ny\n~~~")).to eq("<a\n\n~~~\nx\n\ny\n~~~>")
    end

    it "says which paragraph is the first and which is the last" do
      flags = []
      described_class.map("a\n\nb\n\nc") do |paragraph, first, last|
        flags << [paragraph, first, last]
      end

      expect(flags).to eq([["a", true, false], ["b", false, false], ["c", false, true]])
    end

    it "takes the paragraph in front of a trailing blank line as the last" do
      flags = []
      described_class.map("a\n\nb\n\n") do |paragraph, first, last|
        flags << [paragraph, first, last]
      end

      expect(flags).to eq([["a", true, false], ["b", false, true]])
    end

    it "yields content without a blank line as the first and the last paragraph" do
      flags = []
      described_class.map("a") { |paragraph, first, last| flags << [paragraph, first, last] }

      expect(flags).to eq([["a", true, true]])
    end
  end

  describe ".many?" do
    it "is true for content with a blank line" do
      expect(described_class.many?("a\n\nb")).to be(true)
      expect(described_class.many?("a\n \nb")).to be(true)
    end

    it "is false for content without a blank line" do
      expect(described_class.many?("a\nb")).to be(false)
      expect(described_class.many?("a b")).to be(false)
    end

    it "is false for content with a code fence" do
      expect(described_class.many?("a\n\n```\nx\n```")).to be(false)
      expect(described_class.many?("a\n\n~~~\nx\n~~~")).to be(false)
    end
  end
end
