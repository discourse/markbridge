# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::PeekableEnumerator do
  subject(:enum) { described_class.new(scanner) }

  let(:scanner) { instance_double(Markbridge::Parsers::BBCode::Scanner) }
  let(:tokens) { [1, 2, 3, 4, 5] }

  before do
    token_index = 0
    allow(scanner).to receive(:next_token) do
      if token_index < tokens.size
        tokens[token_index].tap { token_index += 1 }
      else
        nil
      end
    end
  end

  describe "#peek" do
    it "returns next item without consuming it" do
      expect(enum.peek).to eq(1)
      expect(enum.peek).to eq(1) # Still 1
    end

    it "returns nil when peeking past end" do
      5.times { enum.next }
      expect(enum.peek).to be_nil
    end
  end

  describe "#peek_ahead" do
    it "returns array of upcoming items" do
      expect(enum.peek_ahead(3)).to eq([1, 2, 3])
      expect(enum.peek).to eq(1) # Not consumed
    end

    it "returns partial array when fewer items remain" do
      3.times { enum.next }
      expect(enum.peek_ahead(5)).to eq([4, 5])
    end

    it "returns empty array when exhausted" do
      5.times { enum.next }
      expect(enum.peek_ahead(3)).to eq([])
    end

    it "returns empty array when peeking zero items" do
      expect(enum.peek_ahead(0)).to eq([])
    end

    it "clamps negative counts to zero (returns empty array)" do
      expect(enum.peek_ahead(-3)).to eq([])
    end

    it "truncates the buffered tokens to count even when more were already buffered" do
      # Force the buffer to fill to 4 by peeking ahead first
      enum.peek_ahead(4)

      expect(enum.peek_ahead(2)).to eq([1, 2])
    end
  end

  describe "#next" do
    it "returns and consumes next item" do
      expect(enum.next).to eq(1)
      expect(enum.next).to eq(2)
      expect(enum.next).to eq(3)
    end

    it "returns nil when exhausted" do
      5.times { enum.next }
      expect(enum.next).to be_nil
    end

    it "fetches at most one token from the scanner per call" do
      enum.next

      expect(scanner).to have_received(:next_token).once
    end

    it "drains the buffer in FIFO order after a peek_ahead" do
      enum.peek_ahead(3) # buffers [1, 2, 3]

      expect(enum.next).to eq(1)
      expect(enum.next).to eq(2)
      expect(enum.next).to eq(3)
    end
  end

  describe "#peek" do
    it "fetches at most one token from the scanner per call" do
      enum.peek

      expect(scanner).to have_received(:next_token).once
    end
  end

  describe "peek and next interleaved" do
    it "works correctly when mixed" do
      expect(enum.peek).to eq(1)
      expect(enum.next).to eq(1)
      expect(enum.peek).to eq(2)
      expect(enum.peek_ahead(2)).to eq([2, 3])
      expect(enum.next).to eq(2)
      expect(enum.next).to eq(3)
    end
  end
end
