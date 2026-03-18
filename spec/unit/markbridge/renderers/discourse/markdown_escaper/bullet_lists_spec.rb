# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "bullet list markers (-, +, *)" do
    %w[- + *].each do |marker|
      context "with #{marker} marker" do
        context "when at line start followed by space (MUST escape)" do
          it "escapes #{marker} followed by single space" do
            expect(escaper.escape("#{marker} item")).to eq("\\#{marker} item")
          end

          it "escapes #{marker} followed by multiple spaces (up to 4)" do
            expect(escaper.escape("#{marker}    item")).to eq("\\#{marker}    item")
          end

          it "escapes #{marker} followed by tab" do
            expect(escaper.escape("#{marker}\titem")).to eq("\\#{marker}\titem")
          end

          it "escapes #{marker} with 1-3 spaces indent" do
            expect(escaper.escape("   #{marker} item")).to eq("   \\#{marker} item")
          end
        end

        context "when #{marker} is not a list marker (MAY escape - false positives OK)" do
          it "may or may not escape #{marker} not followed by space" do
            result = escaper.escape("#{marker}item")
            expect(result).to eq("#{marker}item").or eq("\\#{marker}item")
          end

          it "may or may not escape #{marker} in middle of line" do
            result = escaper.escape("foo #{marker} bar")
            expect(result).to eq("foo #{marker} bar").or eq("foo \\#{marker} bar")
          end
        end

        context "when #{marker} is followed by end of line (empty list item - MUST escape)" do
          it "escapes #{marker} at end of line" do
            expect(escaper.escape("#{marker}")).to eq("\\#{marker}")
          end

          it "escapes #{marker} followed by newline" do
            result = escaper.escape("#{marker}\nfoo")
            expect(result).to start_with("\\#{marker}\n")
          end

          it "escapes multiline with empty list items" do
            input = "#{marker}\n  foo\n#{marker}\n  bar"
            result = escaper.escape(input)
            # Each list marker should be escaped
            expect(result.scan("\\#{marker}").length).to eq(2)
          end
        end
      end
    end
  end
end
