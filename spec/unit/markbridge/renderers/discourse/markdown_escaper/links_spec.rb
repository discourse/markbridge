# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "links with [ and ]" do
    context "when brackets form link syntax (MUST escape)" do
      # Note: We only need to escape [ - escaping ] is not required
      # because \[text] already breaks the link syntax

      it "escapes inline link" do
        result = escaper.escape("[link](url)")
        expect(result).to start_with("\\[link")
        # ] doesn't need escaping - link is broken by \[
      end

      it "escapes reference link" do
        result = escaper.escape("[link][ref]")
        expect(result).to start_with("\\[link")
      end

      it "escapes shortcut reference link" do
        result = escaper.escape("[link]")
        expect(result).to eq("\\[link]")
      end

      it "escapes collapsed reference link" do
        result = escaper.escape("[link][]")
        expect(result).to start_with("\\[link")
      end
    end

    context "when brackets don't form links (MAY escape - false positives OK)" do
      it "may or may not escape unmatched opening bracket" do
        result = escaper.escape("[unmatched")
        expect(result).to eq("[unmatched").or eq("\\[unmatched")
      end

      it "may or may not escape array-like syntax" do
        result = escaper.escape("array[0]")
        expect(result).to eq("array[0]").or include("\\[")
      end
    end
  end

  describe "images with !" do
    # Note: We only need to escape [ - the ! before it doesn't need escaping
    # because \[ already breaks image syntax (![alt] becomes ![alt] with no link)

    context "when ! precedes [ (MUST escape)" do
      it "escapes image syntax" do
        result = escaper.escape("![alt](url)")
        # Either escape both ![ or just [ - both work
        expect(result).to include("\\[alt")
      end

      it "escapes reference image" do
        result = escaper.escape("![alt][ref]")
        expect(result).to include("\\[alt")
      end

      it "escapes shortcut reference image" do
        result = escaper.escape("![alt]")
        expect(result).to include("\\[alt")
      end
    end

    context "when ! is not before [ (MAY escape - false positives OK)" do
      it "may or may not escape ! not before [" do
        result = escaper.escape("Hello!")
        expect(result).to eq("Hello!").or eq("Hello\\!")
      end

      it "may or may not escape ! with space before [" do
        result = escaper.escape("! [not image]")
        expect(result).to include("[").or include("\\[")
      end
    end
  end

  describe "parentheses in link destinations" do
    context "when ( and ) are unbalanced in link URL (MUST escape)" do
      it "escapes unbalanced ( in URL" do
        # [link](url(foo) - unbalanced, needs escaping
        input = "[link](url(foo)"
        result = escaper.escape(input)
        # Should escape the [ at minimum, may also escape parens
        expect(result).to start_with("\\[")
      end
    end

    context "when parentheses are not in link context (MAY escape - false positives OK)" do
      it "may or may not escape ( outside link context" do
        result = escaper.escape("(parenthetical)")
        expect(result).to eq("(parenthetical)").or include("\\(")
      end

      it "may or may not escape emoticons" do
        result = escaper.escape("smile :)")
        expect(result).to eq("smile :)").or eq("smile :\\)")
      end
    end
  end

  describe "link title delimiters (\", ', ()" do
    context "when quotes are in link title (MAY need escaping inside)" do
      it "handles link with double-quoted title" do
        input = '[link](url "title")'
        result = escaper.escape(input)
        expect(result).to start_with("\\[")
      end

      it "handles link with single-quoted title" do
        input = "[link](url 'title')"
        result = escaper.escape(input)
        expect(result).to start_with("\\[")
      end
    end

    context "when quotes are in regular text (MAY escape - false positives OK)" do
      it "may or may not escape \" in regular text" do
        result = escaper.escape('She said "hello"')
        expect(result).to eq('She said "hello"').or include('\\"')
      end

      it "may or may not escape ' in regular text" do
        result = escaper.escape("it's fine")
        expect(result).to eq("it's fine").or include("\\'")
      end
    end
  end

  describe "#escape with in_link_label: true" do
    # Wrapped in a `#escape` describe so mutant's subject-by-method-name
    # test selection picks these up. Without the wrapper, the example
    # description is e.g. "MarkdownEscaper in_link_label: …" which
    # doesn't include "#escape" and mutant skips it.

    it "escapes ] so it does not close an enclosing link label" do
      result = escaper.escape("[ABC-123] foo", in_link_label: true)
      expect(result).to eq("\\[ABC-123\\] foo")
    end

    it "escapes every ] (not just the first)" do
      result = escaper.escape("[A] and [B]", in_link_label: true)
      expect(result).to eq("\\[A\\] and \\[B\\]")
    end

    it "escapes a bare ] in otherwise unremarkable text" do
      result = escaper.escape("foo ]bar", in_link_label: true)
      expect(result).to eq("foo \\]bar")
    end

    it "leaves text with no ] untouched" do
      result = escaper.escape("plain text", in_link_label: true)
      expect(result).to eq("plain text")
    end

    it "does not escape ] when the flag is false (default)" do
      result = escaper.escape("[ABC-123] foo")
      expect(result).to eq("\\[ABC-123] foo")
    end

    it "returns the input string instance unchanged when no ] is present" do
      # Locks in the no-allocation fast path: when in_link_label is set but
      # the text contains no `]`, escape should return the same object
      # rather than allocate a gsub copy.
      text = "plain text with no closing bracket"
      result = escaper.escape(text, in_link_label: true)
      expect(result).to equal(text)
    end
  end

  describe "link reference definitions" do
    context "when [label]: URL pattern at line start (MUST escape)" do
      it "escapes link reference definition" do
        result = escaper.escape("[ref]: /url")
        # Must escape opening bracket, may also escape closing bracket (false positive OK)
        expect(result).to start_with("\\[ref")
        expect(result).to include("]: /url").or include("\\]: /url")
      end

      it "escapes link reference with title" do
        result = escaper.escape('[ref]: /url "title"')
        expect(result).to start_with("\\[ref")
      end

      it "escapes with 1-3 spaces indent" do
        result = escaper.escape("   [ref]: /url")
        expect(result).to start_with("   \\[ref")
      end

      it "escapes multiline link reference definition" do
        text = "[ref]:\n  /url"
        result = escaper.escape(text)
        expect(result).to start_with("\\[ref")
      end
    end
  end
end
