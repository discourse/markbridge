# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "tables" do
    context "when pipe characters appear in table context (MUST escape)" do
      it "escapes simple table row" do
        input = "| Option | Description |"
        result = escaper.escape(input)
        expect(result).to eq("\\| Option \\| Description \\|")
      end

      it "escapes table header separator with each dash escaped" do
        input = "| ------ | ----------- |"
        result = escaper.escape(input)
        expect(result).to include("\\|")
        # Dashes should be escaped to prevent -- becoming ndash
        expect(result).to include("\\-\\-")
      end

      it "escapes table with right-aligned columns" do
        input = "| ------:| -----------:|"
        result = escaper.escape(input)
        expect(result).to include("\\|")
        expect(result).to include("\\-\\-")
      end

      it "escapes table with left-aligned columns" do
        input = "|:------|:-----------|"
        result = escaper.escape(input)
        expect(result).to include("\\|")
        expect(result).to include("\\-\\-")
      end

      it "escapes table with center-aligned columns" do
        input = "|:------:|:-----------:|"
        result = escaper.escape(input)
        expect(result).to include("\\|")
        expect(result).to include("\\-\\-")
      end

      it "escapes complete table" do
        input = <<~TABLE.chomp
          | Option | Description |
          | ------ | ----------- |
          | data   | path to data files. |
          | engine | engine for templates. |
        TABLE
        result = escaper.escape(input)
        # Every | should be escaped
        expect(result.scan("\\|").length).to eq(input.scan("|").length)
        # Dashes in separator should be escaped
        expect(result).to include("\\-\\-")
      end

      it "escapes table row with content" do
        input =
          "| data   | path to data files to supply the data that will be passed into templates. |"
        result = escaper.escape(input)
        expect(result).to start_with("\\|")
        expect(result).to end_with("\\|")
      end

      it "escapes table without leading pipe" do
        input = "Option | Description"
        result = escaper.escape(input)
        expect(result).to eq("Option \\| Description")
      end

      it "escapes table without trailing pipe" do
        input = "| Option | Description"
        result = escaper.escape(input)
        expect(result).to eq("\\| Option \\| Description")
      end
    end

    context "with complete table examples" do
      it "escapes full table with alignment" do
        input = <<~TABLE.chomp
          | Option | Description |
          | ------:| -----------:|
          | data   | path to data files to supply the data that will be passed into templates. |
          | engine | engine to be used for processing templates. Handlebars is the default. |
          | ext    | extension to be used for dest files. |
        TABLE
        result = escaper.escape(input)
        expect(result).not_to include("\n|")
        expect(result).to include("\n\\|")
        # Dashes in separator should be escaped
        expect(result).to include("\\-\\-")
      end

      it "escapes minimal table (two columns, one row)" do
        input = "| a | b |\n|---|---|\n| 1 | 2 |"
        result = escaper.escape(input)
        expect(result.scan("\\|").length).to eq(9)
        # Dashes should be escaped
        expect(result).to include("\\-\\-\\-")
      end
    end

    context "when pipe appears in non-table context (MAY escape - false positives OK)" do
      it "may or may not escape | in prose" do
        result = escaper.escape("Use the OR operator a | b")
        expect(result).to eq("Use the OR operator a | b").or include("\\|")
      end

      it "may or may not escape | in code mention" do
        result = escaper.escape("The command is: ls | grep foo")
        expect(result).to eq("The command is: ls | grep foo").or include("\\|")
      end

      it "may or may not escape single |" do
        result = escaper.escape("|")
        expect(result).to eq("|").or eq("\\|")
      end
    end
  end
end
