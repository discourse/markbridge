# frozen_string_literal: true

# Direct byte-length unit tests for `utf8_char_length`.
#
# This is a pure function (byte → length) with a well-defined contract that
# is impossible to exercise exhaustively through `#escape` alone: for valid
# UTF-8 input the byte-stream just gets sliced differently but the output
# bytes are identical, so all the boundary mutations are observably
# equivalent through the public API.
#
# The function exists specifically to handle malformed UTF-8 gracefully, so
# we test it directly via a test-only subclass that publicizes it.
RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  let(:exposed_class) { Class.new(described_class) { public :utf8_char_length } }
  let(:escaper) { exposed_class.new }

  describe "#utf8_char_length" do
    {
      0 => 1,
      0x7F => 1, # last single-byte
      0x80 => 1, # continuation byte (treated as 1-byte by length lookup)
      0xBF => 1, # one-below 2-byte lead boundary
      0xC0 => 2, # first 2-byte lead
      0xC1 => 2,
      0xDF => 2, # last 2-byte lead
      0xE0 => 3, # first 3-byte lead
      0xE1 => 3,
      0xEF => 3, # last 3-byte lead
      0xF0 => 4, # first 4-byte lead
      0xF4 => 4,
      0xFF => 4,
    }.each do |byte, expected|
      it "returns #{expected} for byte 0x#{byte.to_s(16).upcase} (#{byte})" do
        expect(escaper.utf8_char_length(byte)).to eq(expected)
      end
    end
  end
end
