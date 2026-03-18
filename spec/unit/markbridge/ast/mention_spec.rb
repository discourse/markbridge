# frozen_string_literal: true

RSpec.describe Markbridge::AST::Mention do
  it "is a Node" do
    mention = described_class.new(name: "gerhard")

    expect(mention).to be_a(Markbridge::AST::Node)
  end

  it "stores name" do
    mention = described_class.new(name: "gerhard")

    expect(mention.name).to eq("gerhard")
  end

  it "defaults type to :user" do
    mention = described_class.new(name: "gerhard")

    expect(mention.type).to eq(:user)
  end

  it "accepts type parameter" do
    mention = described_class.new(name: "Testers", type: :group)

    expect(mention.name).to eq("Testers")
    expect(mention.type).to eq(:group)
  end
end
