# frozen_string_literal: true

RSpec.describe Markbridge::AST::Table do
  it "is an Element" do
    expect(described_class.new).to be_a(Markbridge::AST::Element)
  end

  it "can have children" do
    table = described_class.new
    table << Markbridge::AST::TableRow.new
    expect(table.children.size).to eq(1)
  end
end

RSpec.describe Markbridge::AST::TableRow do
  it "is an Element" do
    expect(described_class.new).to be_a(Markbridge::AST::Element)
  end

  it "can have children" do
    row = described_class.new
    row << Markbridge::AST::TableCell.new
    expect(row.children.size).to eq(1)
  end
end

RSpec.describe Markbridge::AST::TableCell do
  it "is an Element" do
    expect(described_class.new).to be_a(Markbridge::AST::Element)
  end

  it "can have children" do
    cell = described_class.new
    cell << Markbridge::AST::Text.new("content")
    expect(cell.children.size).to eq(1)
  end
end
