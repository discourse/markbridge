# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "emphasis with * (asterisk)" do
    context "when * is flanking (MUST escape)" do
      it "escapes * around word" do
        expect(escaper.escape("*foo*")).to eq("\\*foo\\*")
      end

      it "escapes ** for strong emphasis" do
        expect(escaper.escape("**foo**")).to eq("\\*\\*foo\\*\\*")
      end

      it "escapes * for intraword emphasis" do
        expect(escaper.escape("foo*bar*baz")).to eq("foo\\*bar\\*baz")
      end

      it "escapes * at start of line in paragraph" do
        expect(escaper.escape("text\n*emphasis*")).to eq("text\n\\*emphasis\\*")
      end

      it "escapes *** for bold+italic" do
        expect(escaper.escape("***bold italic***")).to eq("\\*\\*\\*bold italic\\*\\*\\*")
      end
    end

    context "when * is not flanking (MAY escape - false positives OK)" do
      it "may or may not escape * surrounded by spaces" do
        result = escaper.escape("foo * bar * baz")
        expect(result).to eq("foo * bar * baz").or include("\\*")
      end

      it "may or may not escape lone * preceded by space" do
        result = escaper.escape("foo *")
        expect(result).to eq("foo *").or eq("foo \\*")
      end
    end
  end

  describe "emphasis with _ (underscore)" do
    context "when _ is flanking at word boundaries (MUST escape)" do
      it "escapes _ around word" do
        expect(escaper.escape("_foo_")).to eq("\\_foo\\_")
      end

      it "escapes __ for strong emphasis" do
        expect(escaper.escape("__foo__")).to eq("\\_\\_foo\\_\\_")
      end

      it "escapes ___ for bold+italic" do
        expect(escaper.escape("___bold italic___")).to eq("\\_\\_\\_bold italic\\_\\_\\_")
      end
    end

    context "when _ is intraword (MAY escape - CommonMark treats as literal)" do
      # CommonMark does NOT create emphasis for intraword _, but escaping is still OK
      it "may or may not escape _ inside word" do
        result = escaper.escape("foo_bar_baz")
        expect(result).to eq("foo_bar_baz").or eq("foo\\_bar\\_baz")
      end

      it "may or may not escape snake_case identifiers" do
        result = escaper.escape("my_variable_name")
        expect(result).to eq("my_variable_name").or include("\\_")
      end
    end

    context "when _ is not flanking (MAY escape - false positives OK)" do
      it "may or may not escape _ surrounded by spaces" do
        result = escaper.escape("foo _ bar")
        expect(result).to eq("foo _ bar").or eq("foo \\_ bar")
      end
    end
  end
end
