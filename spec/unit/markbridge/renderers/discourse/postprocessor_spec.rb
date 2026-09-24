# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Postprocessor do
  let(:postprocessor) { described_class.new }

  describe "#call" do
    it "collapses runs of three or more newlines to exactly two" do
      expect(postprocessor.call("a\n\n\n\nb")).to eq("a\n\nb")
    end

    it "collapses every run of 3+ newlines, not just the first" do
      # Two distinct runs — `sub` would only catch the first.
      expect(postprocessor.call("a\n\n\nb\n\n\nc")).to eq("a\n\nb\n\nc")
    end

    it "removes whitespace-only lines (preserving multiple of them)" do
      expect(postprocessor.call("a\n   \nb\n\t\nc")).to eq("a\n\nb\n\nc")
    end

    it "strips leading and trailing whitespace from the document" do
      expect(postprocessor.call("   hi   ")).to eq("hi")
    end

    it "leaves a single blank line between paragraphs alone" do
      expect(postprocessor.call("a\n\nb")).to eq("a\n\nb")
    end

    context "with fenced code blocks" do
      it "keeps blank lines inside a fence" do
        text = "```\na\n\n\n\nb\n```"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "keeps whitespace-only lines inside a fence" do
        text = "```\na\n   \nb\n```"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "still cleans the text before and after a fence" do
        expect(postprocessor.call("a\n\n\n\n```\nx\n\n\n```\n\n\n\nb")).to eq(
          "a\n\n```\nx\n\n\n```\n\nb",
        )
      end

      it "recognizes an indented fence, as inside a list item" do
        text = "- item\n\n  ```\n  a\n\n\n  b\n  ```"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "recognizes a fence that follows a list marker on the same line" do
        text = "- ```\n  a\n\n\n  b\n  ```"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "recognizes a fence behind two nested list markers" do
        text = "1. - ~~~\n     a\n\n\n     b\n     ~~~"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "cleans the text after an indented fence that closes" do
        expect(postprocessor.call("- item\n\n  ```\n  a\n  ```\n\n\n\n  b")).to eq(
          "- item\n\n  ```\n  a\n  ```\n\n  b",
        )
      end

      it "hands back a fenced document that has nothing to clean" do
        text = "```\na\n```\n\nb"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "clears a whitespace-only line next to a fence" do
        # The only thing to clean here is the line of spaces, and there is
        # no run of three newlines anywhere.
        expect(postprocessor.call("```\na\n```\n   \nb")).to eq("```\na\n```\n\nb")
      end

      it "closes a fence whose closing run has trailing spaces" do
        expect(postprocessor.call("```\na\n```  \n\n\n\nb")).to eq("```\na\n```  \n\nb")
      end

      it "keeps a tilde fence open when its info string has a backtick" do
        text = "~~~ x`y\na\n\n\n\nb\n~~~"
        expect(postprocessor.call(text)).to eq(text)
      end

      # Both fence kinds in one document, in both orders: the scan has to
      # take whichever comes first, and the blank lines inside each block
      # have to survive while the ones between them are collapsed.
      it "keeps a backtick block and a tilde block that follows it" do
        text = "```\nx\n\n\n\ny\n```\n\n\n\n~~~\np\n\n\n\nq\n~~~"
        expect(postprocessor.call(text)).to eq("```\nx\n\n\n\ny\n```\n\n~~~\np\n\n\n\nq\n~~~")
      end

      it "keeps a tilde block and a backtick block that follows it" do
        text = "~~~\nx\n\n\n\ny\n~~~\n\n\n\n```\np\n\n\n\nq\n```"
        expect(postprocessor.call(text)).to eq("~~~\nx\n\n\n\ny\n~~~\n\n```\np\n\n\n\nq\n```")
      end

      it "closes a fence opened behind a list marker on a line without the marker" do
        expect(postprocessor.call("- ```\n  a\n  ```\n\n\n\n- b")).to eq("- ```\n  a\n  ```\n\n- b")
      end

      it "handles an opening fence on the last line" do
        expect(postprocessor.call("a\n\n\n\n```")).to eq("a\n\n```")
      end

      it "keeps looking for a fence after a backtick run that opens none" do
        text = "``` x`y\n```\na\n\n\n\nb\n```"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "leaves a code span with a long delimiter and the text around it alone" do
        expect(postprocessor.call("a ```` x ```` b\n\n\n\nc")).to eq("a ```` x ```` b\n\nc")
      end

      it "recognizes a tilde fence" do
        text = "~~~\na\n\n\n\nb\n~~~"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "does not close a tilde fence on a backtick line" do
        text = "~~~\na\n```\n\n\n\nb\n~~~"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "does not close a fence with a shorter run" do
        text = "````\na\n```\n\n\n\nb\n````"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "closes a fence with a longer run" do
        expect(postprocessor.call("```\na\n`````\n\n\n\nb")).to eq("```\na\n`````\n\nb")
      end

      it "does not close a fence on a line that has text after the run" do
        text = "```\na\n``` x\n\n\n\nb\n```"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "runs an unclosed fence to the end of the text" do
        text = "```\na\n\n\n\nb"
        expect(postprocessor.call(text)).to eq(text)
      end

      it "does not treat a backtick run followed by a backtick as a fence" do
        expect(postprocessor.call("``` a ` b\n\n\n\nc")).to eq("``` a ` b\n\nc")
      end

      it "cleans text with a fence character run that opens no fence" do
        expect(postprocessor.call("`` a\n\n\n\nb")).to eq("`` a\n\nb")
      end

      it "does not strip trailing invisibles inside a fence" do
        zwsp = "\u200B"
        text = "```\nx#{zwsp}\n```\n\ny#{zwsp}"
        expect(described_class.new(strip_trailing_invisibles: true).call(text)).to eq(
          "```\nx#{zwsp}\n```\n\ny",
        )
      end
    end

    context "with the default strip_trailing_invisibles: false" do
      it "keeps trailing ZWSP at line ends" do
        # U+200B is a real character in the output; default Postprocessor
        # leaves it alone.
        zwsp = "​"
        expect(postprocessor.call("hello#{zwsp}\nworld")).to eq("hello#{zwsp}\nworld")
      end

      it "keeps trailing NBSP at line ends" do
        nbsp = " "
        expect(postprocessor.call("hello#{nbsp}\nworld")).to eq("hello#{nbsp}\nworld")
      end
    end

    context "with strip_trailing_invisibles: true" do
      let(:postprocessor) { described_class.new(strip_trailing_invisibles: true) }

      it "strips trailing zero-width space at the end of a line" do
        zwsp = "​"
        expect(postprocessor.call("hello#{zwsp}\nworld")).to eq("hello\nworld")
      end

      it "strips trailing nbsp at the end of a line" do
        nbsp = " "
        expect(postprocessor.call("hello#{nbsp}\nworld")).to eq("hello\nworld")
      end

      it "strips every recognised invisible (ZWSP, ZWNJ, ZWJ, WJ, ZWNBSP) at end of line" do
        # All five zero-width format chars covered by TRAILING_INVISIBLE_RE.
        invisibles = "​‌‍⁠﻿"
        expect(postprocessor.call("hello#{invisibles}\nworld")).to eq("hello\nworld")
      end

      it "preserves trailing ASCII spaces — they encode Markdown hard line breaks" do
        # `hello  \nworld` (two trailing spaces) is the hard-line-break form;
        # the trailing-invisibles strip must not touch ASCII spaces.
        expect(postprocessor.call("hello  \nworld")).to eq("hello  \nworld")
      end

      it "preserves invisibles in the middle of content (only end-of-line is stripped)" do
        zwsp = "​"
        expect(postprocessor.call("before#{zwsp}inside")).to eq("before#{zwsp}inside")
      end

      it "strips trailing invisibles on every affected line, not just the first" do
        # gsub vs sub: with sub, only the first line's ZWSP gets cleaned.
        zwsp = "​"
        expect(postprocessor.call("first#{zwsp}\nsecond#{zwsp}")).to eq("first\nsecond")
      end
    end
  end

  describe "DEFAULT" do
    it "is a Postprocessor instance" do
      expect(described_class::DEFAULT).to be_a(described_class)
    end

    it "behaves like a fresh instance" do
      expect(described_class::DEFAULT.call("a\n\n\nb")).to eq("a\n\nb")
    end
  end

  describe "as a Renderer dependency" do
    it "is invoked by Markbridge.bbcode_to_markdown via the renderer" do
      custom =
        Class.new(described_class) do
          def call(text)
            "PROCESSED:#{text.strip}"
          end
        end

      renderer = Markbridge.discourse_renderer(postprocessor: custom.new)

      expect(Markbridge.bbcode_to_markdown("[b]hi[/b]", renderer:).markdown).to eq(
        "PROCESSED:**hi**",
      )
    end
  end
end
