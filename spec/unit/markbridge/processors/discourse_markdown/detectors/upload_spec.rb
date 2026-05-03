# frozen_string_literal: true

RSpec.describe Markbridge::Processors::DiscourseMarkdown::Detectors::Upload do
  subject(:detector) { described_class.new }

  describe "#detect" do
    context "with image uploads" do
      it "detects image upload" do
        input = "![alt](upload://abc123.png)"
        match = detector.detect(input, 0)

        expect(match).not_to be_nil
        expect(match.start_pos).to eq(0)
        expect(match.end_pos).to eq(input.length)
        expect(match.node).to be_a(Markbridge::AST::Upload)
        expect(match.node.type).to eq(:image)
      end

      it "extracts sha1 from URL" do
        input = "![](upload://RBhXLF6381Te3mneJQNnnyNNt5.png)"
        match = detector.detect(input, 0)

        expect(match.node.sha1).to eq("RBhXLF6381Te3mneJQNnnyNNt5")
      end

      it "extracts alt text" do
        input = "![My Image](upload://abc.png)"
        match = detector.detect(input, 0)

        expect(match.node.alt).to eq("My Image")
      end

      it "extracts dimensions from alt" do
        input = "![logo|64x64](upload://abc.png)"
        match = detector.detect(input, 0)

        expect(match.node.alt).to eq("logo")
        expect(match.node.dimensions).to eq("64x64")
      end

      it "handles alt with only dimensions" do
        input = "![|64x64](upload://abc.png)"
        match = detector.detect(input, 0)

        expect(match.node.alt).to be_nil
        expect(match.node.dimensions).to eq("64x64")
      end

      it "stores raw markdown" do
        input = "![alt](upload://abc.png)"
        match = detector.detect(input, 0)

        expect(match.node.raw).to eq(input)
      end

      it "returns nil when not at !" do
        match = detector.detect("text ![img](upload://abc.png)", 0)

        expect(match).to be_nil
      end

      it "returns nil for non-upload URL" do
        match = detector.detect("![img](https://example.com/img.png)", 0)

        expect(match).to be_nil
      end
    end

    context "with attachment uploads" do
      it "detects attachment upload" do
        input = "[doc.pdf|attachment](upload://xyz789.pdf)"
        match = detector.detect(input, 0)

        expect(match).not_to be_nil
        expect(match.node.type).to eq(:attachment)
      end

      it "extracts filename" do
        input = "[document.pdf|attachment](upload://xyz789.pdf)"
        match = detector.detect(input, 0)

        expect(match.node.filename).to eq("document.pdf")
      end

      it "extracts sha1" do
        input = "[doc.pdf|attachment](upload://ppJp89TTiLOo6Vl4mAmo21MV28w.pdf)"
        match = detector.detect(input, 0)

        expect(match.node.sha1).to eq("ppJp89TTiLOo6Vl4mAmo21MV28w")
      end

      it "extracts size when present" do
        input = "[doc.pdf|attachment](upload://xyz.pdf) (502.1 KB)"
        match = detector.detect(input, 0)

        expect(match.node.size).to eq("502.1 KB")
      end

      it "handles missing size" do
        input = "[doc.pdf|attachment](upload://xyz.pdf)"
        match = detector.detect(input, 0)

        expect(match.node.size).to be_nil
      end

      it "stores raw markdown" do
        input = "[doc.pdf|attachment](upload://xyz.pdf) (1 MB)"
        match = detector.detect(input, 0)

        expect(match.node.raw).to eq(input)
      end

      it "returns nil for regular link without |attachment" do
        match = detector.detect("[link](upload://abc.pdf)", 0)

        expect(match).to be_nil
      end

      it "returns nil when not at [" do
        match = detector.detect("text [doc|attachment](upload://abc.pdf)", 0)

        expect(match).to be_nil
      end
    end

    context "with edge cases" do
      it "handles [ that is image (![)" do
        input = "![](upload://abc.png)"
        match = detector.detect(input, 1) # At [ after !

        expect(match).to be_nil # Should not match partial
      end
    end

    context "when detecting at a non-zero position" do
      it "detects image upload at the given position" do
        input = "prefix ![alt](upload://abc.png) suffix"
        match = detector.detect(input, 7)

        expect(match).not_to be_nil
        expect(match.start_pos).to eq(7)
        expect(match.end_pos).to eq(input.length - " suffix".length)
        expect(match.node.raw).to eq("![alt](upload://abc.png)")
      end

      it "detects attachment upload at the given position" do
        input = "prefix [doc.pdf|attachment](upload://xyz.pdf) suffix"
        match = detector.detect(input, 7)

        expect(match).not_to be_nil
        expect(match.start_pos).to eq(7)
        expect(match.end_pos).to eq(input.length - " suffix".length)
        expect(match.node.raw).to eq("[doc.pdf|attachment](upload://xyz.pdf)")
      end
    end

    context "with an image upload URL that has an extension" do
      it "sets the filename on the node" do
        input = "![alt](upload://abc.png)"
        match = detector.detect(input, 0)

        expect(match.node.filename).to eq("abc.png")
      end
    end

    context "with an image upload URL that has no extension" do
      it "leaves filename nil on the node" do
        input = "![alt](upload://abc123)"
        match = detector.detect(input, 0)

        expect(match.node.filename).to be_nil
      end
    end
  end
end
