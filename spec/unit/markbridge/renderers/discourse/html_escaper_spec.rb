# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markbridge::Renderers::Discourse::HtmlEscaper do
  let(:escaper) { described_class.new }

  describe "#escape" do
    it "returns empty string for nil" do
      expect(escaper.escape(nil)).to eq("")
    end

    it "returns empty string for empty input" do
      expect(escaper.escape("")).to eq("")
    end

    it "escapes &, <, >, \", '" do
      expect(escaper.escape(%(&<>"'))).to eq("&amp;&lt;&gt;&quot;&#39;")
    end

    it "passes plain text through unchanged" do
      expect(escaper.escape("hello world")).to eq("hello world")
    end

    it "passes multibyte text through unchanged" do
      expect(escaper.escape("café — naïve")).to eq("café — naïve")
    end
  end

  describe ".escape" do
    it "matches the instance method behaviour" do
      expect(described_class.escape(%(<a href="x">))).to eq("&lt;a href=&quot;x&quot;&gt;")
    end

    it "returns empty string for nil" do
      expect(described_class.escape(nil)).to eq("")
    end
  end
end
