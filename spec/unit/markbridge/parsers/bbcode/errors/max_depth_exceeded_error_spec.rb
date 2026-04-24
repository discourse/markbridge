# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::MaxDepthExceededError do
  # Kills `super("...")` → `super`. The explicit message is the only
  # observable part of the error; `super` without args would pass the
  # constructor's receiver args, producing a different (or empty)
  # message.
  it "includes the max depth in the message" do
    error = described_class.new(100)

    expect(error.message).to eq("maximum parsing depth (100) exceeded")
  end

  it "is a StandardError subclass" do
    expect(described_class.ancestors).to include(StandardError)
  end
end
