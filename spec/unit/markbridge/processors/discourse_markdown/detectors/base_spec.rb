# frozen_string_literal: true

RSpec.describe Markbridge::Processors::DiscourseMarkdown::Detectors::Base do
  # Test subclass that exposes the private helpers for direct testing.
  subject(:detector) { test_detector_class.new }

  let(:test_detector_class) do
    Class.new(described_class) { public :word_boundary?, :extract_word, :parse_attributes }
  end

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

  describe "#word_boundary?" do
    it "is true at the start of the input" do
      expect(detector.word_boundary?("@user", 0)).to be true
    end

    it "is true after whitespace" do
      expect(detector.word_boundary?("hi @user", 3)).to be true
    end

    it "is true after a non-word character" do
      expect(detector.word_boundary?("(@user)", 1)).to be true
    end

    it "is false when the previous character is a word character" do
      expect(detector.word_boundary?("hi@user", 2)).to be false
    end

    it "is false when the previous character is a digit" do
      expect(detector.word_boundary?("1@user", 1)).to be false
    end

    it "is false when the previous character is an underscore" do
      expect(detector.word_boundary?("_@user", 1)).to be false
    end
  end

  describe "#extract_word" do
    it "returns the word starting at pos" do
      expect(detector.extract_word("@gerhard!", 1)).to eq("gerhard")
    end

    it "returns an empty string when the starting character isn't word-like" do
      expect(detector.extract_word("@!foo", 1)).to eq("")
    end

    it "includes hyphens in the extracted word" do
      expect(detector.extract_word("user-name!", 0)).to eq("user-name")
    end

    it "stops at the end of the input" do
      expect(detector.extract_word("foo", 0)).to eq("foo")
    end

    it "returns an empty string when pos is at the end" do
      expect(detector.extract_word("foo", 3)).to eq("")
    end

    it "returns an empty string when pos is past the end" do
      expect(detector.extract_word("foo", 10)).to eq("")
    end
  end

  describe "#parse_attributes" do
    it "returns an empty hash for nil input" do
      expect(detector.parse_attributes(nil)).to eq({})
    end

    it "returns an empty hash for empty input" do
      expect(detector.parse_attributes("")).to eq({})
    end

    it "parses double-quoted attribute pairs" do
      expect(detector.parse_attributes(' name="Meeting"')).to eq("name" => "Meeting")
    end

    it "parses single-quoted attribute pairs" do
      expect(detector.parse_attributes(" name='Meeting'")).to eq("name" => "Meeting")
    end

    it "parses multiple attributes" do
      expect(detector.parse_attributes(' name="A" start="B"')).to eq("name" => "A", "start" => "B")
    end

    it "downcases attribute keys" do
      expect(detector.parse_attributes(' ChartType="pie"')).to eq("charttype" => "pie")
    end

    it "preserves value case" do
      expect(detector.parse_attributes(' x="MixedCase"')).to eq("x" => "MixedCase")
    end

    it "ignores content without valid attribute pairs" do
      expect(detector.parse_attributes(" garbage without equals")).to eq({})
    end

    it "handles empty attribute values" do
      expect(detector.parse_attributes(' name=""')).to eq("name" => "")
    end
  end
end
