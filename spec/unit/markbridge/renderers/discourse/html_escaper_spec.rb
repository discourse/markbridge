# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markbridge::Renderers::Discourse::HtmlEscaper do
  describe ".escape" do
    it "returns empty string for nil" do
      expect(described_class.escape(nil)).to eq("")
    end

    it "returns empty string for empty input" do
      expect(described_class.escape("")).to eq("")
    end

    it "escapes &, <, >, \", '" do
      expect(described_class.escape(%(&<>"'))).to eq("&amp;&lt;&gt;&quot;&#39;")
    end

    it "passes plain text through unchanged" do
      expect(described_class.escape("hello world")).to eq("hello world")
    end

    it "passes multibyte text through unchanged" do
      expect(described_class.escape("café — naïve")).to eq("café — naïve")
    end
  end
end
