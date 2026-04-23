# frozen_string_literal: true

RSpec.describe Markbridge::ParserStuckError do
  it "includes the parser class and position in its message" do
    # Kills the `#{parser}` → `#{nil}` mutation on the message
    # construction by asserting the class name appears literally.
    error = described_class.new(parser: Markbridge::Parsers::BBCode::Scanner, pos: 42)

    expect(error.message).to eq(
      "Markbridge::Parsers::BBCode::Scanner stuck at position 42 — " \
        "dispatch did not advance the cursor",
    )
  end
end
