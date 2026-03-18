# frozen_string_literal: true

RSpec.describe Markbridge::Processors::DiscourseMarkdown::Detectors::Mention do
  subject(:detector) { described_class.new }

  describe "#detect" do
    it "detects mention at start of input" do
      match = detector.detect("@gerhard", 0)

      expect(match).not_to be_nil
      expect(match.start_pos).to eq(0)
      expect(match.end_pos).to eq(8)
      expect(match.node).to be_a(Markbridge::AST::Mention)
      expect(match.node.name).to eq("gerhard")
    end

    it "detects mention in middle of text" do
      match = detector.detect("Hello @gerhard!", 6)

      expect(match).not_to be_nil
      expect(match.start_pos).to eq(6)
      expect(match.end_pos).to eq(14)
      expect(match.node.name).to eq("gerhard")
    end

    it "returns nil when not at @" do
      match = detector.detect("Hello @gerhard", 0)

      expect(match).to be_nil
    end

    it "returns nil for @ not at word boundary" do
      match = detector.detect("email@example.com", 5)

      expect(match).to be_nil
    end

    it "returns nil for @ with no following name" do
      match = detector.detect("@ alone", 0)

      expect(match).to be_nil
    end

    it "handles usernames with hyphens" do
      match = detector.detect("@user-name", 0)

      expect(match).not_to be_nil
      expect(match.node.name).to eq("user-name")
    end

    it "handles usernames with underscores" do
      match = detector.detect("@user_name", 0)

      expect(match).not_to be_nil
      expect(match.node.name).to eq("user_name")
    end

    it "handles usernames with numbers" do
      match = detector.detect("@user123", 0)

      expect(match).not_to be_nil
      expect(match.node.name).to eq("user123")
    end

    it "stops at non-word characters" do
      match = detector.detect("@gerhard!", 0)

      expect(match.end_pos).to eq(8)
      expect(match.node.name).to eq("gerhard")
    end

    it "detects mention after newline" do
      match = detector.detect("line1\n@gerhard", 6)

      expect(match).not_to be_nil
      expect(match.node.name).to eq("gerhard")
    end

    it "detects mention after space" do
      match = detector.detect("cc @gerhard", 3)

      expect(match).not_to be_nil
      expect(match.node.name).to eq("gerhard")
    end
  end
end
