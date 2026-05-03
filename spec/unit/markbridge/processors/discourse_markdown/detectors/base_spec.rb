# frozen_string_literal: true

RSpec.describe Markbridge::Processors::DiscourseMarkdown::Detectors::Base do
  describe "#detect" do
    it "raises NotImplementedError (abstract method)" do
      expect { described_class.new.detect("input", 0) }.to raise_error(
        NotImplementedError,
        /must implement #detect/,
      )
    end

    it "includes the subclass name in the error message" do
      klass = Class.new(described_class)
      stub_const("MyCustomDetector", klass)

      expect { klass.new.detect("x", 0) }.to raise_error(
        NotImplementedError,
        /\AMyCustomDetector must implement/,
      )
    end
  end

  # The private helpers below are exercised through concrete detectors
  # (Mention, Event, Poll). Each test is tagged with `mutant_expression:`
  # so mutant counts it toward Base's helper coverage even though the
  # describe block is named after the concrete class.

  describe "#word_boundary? (via Mention#detect)" do
    let(:mention) { Markbridge::Processors::DiscourseMarkdown::Detectors::Mention.new }

    it "is true at the start of the input" do
      expect(mention.detect("@user", 0)).not_to be_nil
    end

    it "is true after whitespace" do
      expect(mention.detect("hi @user", 3)).not_to be_nil
    end

    it "is true after a non-word character (open paren)" do
      expect(mention.detect("(@user)", 1)).not_to be_nil
    end

    it "is true after a non-word character (period)" do
      expect(mention.detect(".@user", 1)).not_to be_nil
    end

    it "is false when the previous character is a word letter" do
      expect(mention.detect("hi@user", 2)).to be_nil
    end

    it "is false when the previous character is a digit" do
      expect(mention.detect("1@user", 1)).to be_nil
    end

    it "is false when the previous character is an underscore" do
      expect(mention.detect("_@user", 1)).to be_nil
    end
  end

  describe "#extract_word (via Mention#detect)" do
    let(:mention) { Markbridge::Processors::DiscourseMarkdown::Detectors::Mention.new }

    it "extracts a word starting at pos+1" do
      match = mention.detect("@gerhard!", 0)
      expect(match.node.name).to eq("gerhard")
    end

    it "returns nil when the starting character isn't word-like (empty extract)" do
      expect(mention.detect("@!foo", 0)).to be_nil
    end

    it "includes hyphens in the extracted word" do
      match = mention.detect("@user-name!", 0)
      expect(match.node.name).to eq("user-name")
    end

    it "stops at the end of the input" do
      match = mention.detect("@foo", 0)
      expect(match.node.name).to eq("foo")
    end

    it "returns nil when there is no word after @" do
      # The character after @ is the end of input → empty word → no match
      expect(mention.detect("@", 0)).to be_nil
    end
  end

  describe "#parse_attributes (via Event#detect)" do
    let(:event) { Markbridge::Processors::DiscourseMarkdown::Detectors::Event.new }

    it "parses double-quoted attribute pairs" do
      match = event.detect('[event name="M" start="2025-01-01"][/event]', 0)
      expect(match.node.starts_at).to eq("2025-01-01")
    end

    it "parses single-quoted attribute pairs" do
      match = event.detect("[event name='M' start='2025-01-01'][/event]", 0)
      expect(match.node.starts_at).to eq("2025-01-01")
    end

    it "parses multiple attributes in one tag" do
      match = event.detect('[event name="M" start="2025" end="2026"][/event]', 0)
      expect(match.node.starts_at).to eq("2025")
      expect(match.node.ends_at).to eq("2026")
    end

    it "downcases attribute keys (preserves value case)" do
      match = event.detect('[event Name="MixedCase" Start="2025"][/event]', 0)
      expect(match.node.name).to eq("MixedCase")
    end

    it "handles empty attribute values" do
      match = event.detect('[event name="" start="2025"][/event]', 0)
      expect(match.node.name).to eq("")
    end

    it "returns nil when no attribute pairs are present (parse → empty hash → required attrs missing)" do
      expect(event.detect("[event][/event]", 0)).to be_nil
    end

    it "ignores garbage between attribute pairs without crashing" do
      match = event.detect('[event name="M" garbage start="2025"][/event]', 0)
      expect(match.node.name).to eq("M")
      expect(match.node.starts_at).to eq("2025")
    end
  end
end
