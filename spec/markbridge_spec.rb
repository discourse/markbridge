# frozen_string_literal: true

RSpec.describe Markbridge do
  after { described_class.reset_defaults! }

  it "has a version number" do
    expect(Markbridge::VERSION).not_to be nil
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(Markbridge::Configuration)
    end

    it "memoizes the configuration" do
      expect(described_class.configuration).to be(described_class.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure { |config| expect(config).to be(described_class.configuration) }
    end
  end

  describe ".reset_defaults!" do
    it "resets the configuration" do
      old_config = described_class.configuration
      described_class.reset_defaults!
      expect(described_class.configuration).not_to be(old_config)
    end
  end

  describe ".bbcode_to_markdown" do
    it "respects escape_hard_line_breaks configuration" do
      described_class.configure { |c| c.escape_hard_line_breaks = true }

      result = described_class.bbcode_to_markdown("hello  \nworld")
      expect(result).to eq("hello\nworld")
    end
  end
end
