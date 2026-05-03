# frozen_string_literal: true

RSpec.describe Markbridge::AST::Table do
  it "is an Element" do
    expect(described_class.new).to be_a(Markbridge::AST::Element)
  end

  it "can have TableRow children" do
    table = described_class.new
    row = Markbridge::AST::TableRow.new
    table << row

    expect(table.children).to eq([row])
  end

  it "ignores whitespace-only Text children" do
    table = described_class.new
    table << Markbridge::AST::Text.new("  \n  ")

    expect(table.children).to be_empty
  end

  it "preserves non-whitespace Text children" do
    table = described_class.new
    text = Markbridge::AST::Text.new("content")
    table << text

    expect(table.children).to eq([text])
  end

  it "returns self when skipping whitespace Text (for chaining)" do
    table = described_class.new
    result = table << Markbridge::AST::Text.new("  ")

    # Kills `return self` → `return nil` / `return child` mutations.
    expect(result).to eq(table)
  end

  it "only skips Text whitespace, not other whitespace-stringified nodes" do
    # Kills `is_a?(Text)` → `is_a?(Node)` / `true` / drop. A Paragraph
    # that happens to stringify to whitespace must still be added.
    table = described_class.new
    para = Markbridge::AST::Paragraph.new
    table << para

    expect(table.children).to eq([para])
  end

  it "preserves Text that is only a newline (non-empty after strip check)" do
    # Kills `.strip.empty?` → `.strip` (truthy) mutations. A Text with
    # just "\n" strips to "" and should be skipped.
    table = described_class.new
    table << Markbridge::AST::Text.new("\n")

    expect(table.children).to be_empty
  end
end

RSpec.describe Markbridge::AST::TableRow do
  it "is an Element" do
    expect(described_class.new).to be_a(Markbridge::AST::Element)
  end

  it "can have TableCell children" do
    row = described_class.new
    cell = Markbridge::AST::TableCell.new
    row << cell

    expect(row.children).to eq([cell])
  end

  it "ignores whitespace-only Text children" do
    row = described_class.new
    row << Markbridge::AST::Text.new("  \n  ")

    expect(row.children).to be_empty
  end

  it "returns self when skipping whitespace Text (for chaining)" do
    row = described_class.new
    result = row << Markbridge::AST::Text.new("  ")

    expect(result).to eq(row)
  end

  it "preserves a non-whitespace Text child" do
    row = described_class.new
    text = Markbridge::AST::Text.new("bare text")
    row << text

    expect(row.children).to eq([text])
  end
end

RSpec.describe Markbridge::AST::TableCell do
  it "is an Element" do
    expect(described_class.new).to be_a(Markbridge::AST::Element)
  end

  describe "#header?" do
    it "returns false by default" do
      expect(described_class.new.header?).to be false
    end

    it "returns true when created as header" do
      expect(described_class.new(header: true).header?).to be true
    end

    it "returns false when created as non-header" do
      expect(described_class.new(header: false).header?).to be false
    end
  end

  it "can have Text children" do
    cell = described_class.new
    text = Markbridge::AST::Text.new("content")
    cell << text

    expect(cell.children).to eq([text])
  end
end
