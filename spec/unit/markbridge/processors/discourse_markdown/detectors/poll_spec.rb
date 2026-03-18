# frozen_string_literal: true

RSpec.describe Markbridge::Processors::DiscourseMarkdown::Detectors::Poll do
  subject(:detector) { described_class.new }

  describe "#detect" do
    it "detects simple poll" do
      input = "[poll]\n* A\n* B\n[/poll]"
      match = detector.detect(input, 0)

      expect(match).not_to be_nil
      expect(match.start_pos).to eq(0)
      expect(match.end_pos).to eq(input.length)
      expect(match.node).to be_a(Markbridge::AST::Poll)
    end

    it "returns nil when not at [" do
      match = detector.detect("text [poll][/poll]", 0)

      expect(match).to be_nil
    end

    it "returns nil for non-poll tag" do
      match = detector.detect("[bold]text[/bold]", 0)

      expect(match).to be_nil
    end

    it "returns nil when closing tag is missing" do
      match = detector.detect("[poll]\n* A", 0)

      expect(match).to be_nil
    end

    it "extracts poll name" do
      input = '[poll name="my-poll"][/poll]'
      match = detector.detect(input, 0)

      expect(match.node.name).to eq("my-poll")
    end

    it "defaults poll name to 'poll'" do
      input = "[poll][/poll]"
      match = detector.detect(input, 0)

      expect(match.node.name).to eq("poll")
    end

    it "extracts poll type" do
      input = '[poll type="multiple"][/poll]'
      match = detector.detect(input, 0)

      expect(match.node.type).to eq("multiple")
    end

    it "extracts poll results setting" do
      input = '[poll results="on_vote"][/poll]'
      match = detector.detect(input, 0)

      expect(match.node.results).to eq("on_vote")
    end

    it "extracts public flag" do
      input = '[poll public="true"][/poll]'
      match = detector.detect(input, 0)

      expect(match.node.public).to be true
    end

    it "extracts chart type (camelCase)" do
      input = '[poll chartType="pie"][/poll]'
      match = detector.detect(input, 0)

      expect(match.node.chart_type).to eq("pie")
    end

    it "extracts chart type (lowercase)" do
      input = '[poll charttype="bar"][/poll]'
      match = detector.detect(input, 0)

      expect(match.node.chart_type).to eq("bar")
    end

    it "extracts options from unordered list with *" do
      input = "[poll]\n* Option A\n* Option B\n[/poll]"
      match = detector.detect(input, 0)

      expect(match.node.options).to eq(["Option A", "Option B"])
    end

    it "extracts options from unordered list with -" do
      input = "[poll]\n- Option A\n- Option B\n[/poll]"
      match = detector.detect(input, 0)

      expect(match.node.options).to eq(["Option A", "Option B"])
    end

    it "extracts options from ordered list" do
      input = "[poll]\n1. First\n2. Second\n[/poll]"
      match = detector.detect(input, 0)

      expect(match.node.options).to eq(%w[First Second])
    end

    it "stores raw BBCode" do
      input = "[poll]\n* A\n[/poll]"
      match = detector.detect(input, 0)

      expect(match.node.raw).to eq(input)
    end

    it "handles single-quoted attributes" do
      input = "[poll type='regular'][/poll]"
      match = detector.detect(input, 0)

      expect(match.node.type).to eq("regular")
    end

    it "is case-insensitive for tag name" do
      input = "[POLL][/POLL]"
      match = detector.detect(input, 0)

      expect(match).not_to be_nil
    end
  end
end
