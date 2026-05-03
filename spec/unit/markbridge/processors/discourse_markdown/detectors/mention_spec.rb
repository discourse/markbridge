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

    it "defaults the mention type to :user when no resolver is given" do
      match = detector.detect("@gerhard", 0)

      expect(match.node.type).to eq(:user)
    end

    context "with a type resolver" do
      it "uses the resolver's result as the mention type" do
        resolver = ->(name) { name == "Testers" ? :group : :user }
        detector = described_class.new(type_resolver: resolver)

        expect(detector.detect("@Testers", 0).node.type).to eq(:group)
        expect(detector.detect("@gerhard", 0).node.type).to eq(:user)
      end

      it "falls back to :user when the resolver returns nil" do
        resolver = ->(_name) { nil }
        detector = described_class.new(type_resolver: resolver)

        expect(detector.detect("@x", 0).node.type).to eq(:user)
      end

      it "passes the resolved name (not the whole input) to the resolver" do
        received = nil
        resolver = ->(name) do
          received = name
          :user
        end
        detector = described_class.new(type_resolver: resolver)

        detector.detect("hi @alice!", 3)

        expect(received).to eq("alice")
      end
    end
  end
end
