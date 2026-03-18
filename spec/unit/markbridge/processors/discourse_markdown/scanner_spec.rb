# frozen_string_literal: true

RSpec.describe Markbridge::Processors::DiscourseMarkdown::Scanner do
  subject(:scanner) { described_class.new }

  describe "#scan" do
    it "returns ScanResult with markdown and nodes" do
      result = scanner.scan("Hello @world")

      expect(result).to be_a(Markbridge::Processors::DiscourseMarkdown::ScanResult)
      expect(result.markdown).to be_a(String)
      expect(result.nodes).to be_an(Array)
    end

    it "handles empty input" do
      result = scanner.scan("")

      expect(result.markdown).to eq("")
      expect(result.nodes).to be_empty
    end

    it "handles nil input" do
      result = scanner.scan(nil)

      expect(result.markdown).to eq("")
      expect(result.nodes).to be_empty
    end

    it "preserves text without constructs" do
      input = "Hello, this is plain text."
      result = scanner.scan(input)

      expect(result.markdown).to eq(input)
      expect(result.nodes).to be_empty
    end

    context "with mentions" do
      it "detects user mentions" do
        result = scanner.scan("Hello @gerhard!")

        expect(result.markdown).to eq("Hello <<MENTION:0:gerhard>>!")
        expect(result.nodes.size).to eq(1)
        expect(result.nodes.first).to be_a(Markbridge::AST::Mention)
        expect(result.nodes.first.name).to eq("gerhard")
      end

      it "detects multiple mentions" do
        result = scanner.scan("@alice and @bob")

        expect(result.markdown).to eq("<<MENTION:0:alice>> and <<MENTION:1:bob>>")
        expect(result.nodes.size).to eq(2)
      end

      it "skips mentions in fenced code blocks" do
        input = "```\n@gerhard\n```"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end

      it "skips mentions in inline code" do
        result = scanner.scan("Use `@gerhard` syntax")

        expect(result.markdown).to eq("Use `@gerhard` syntax")
        expect(result.nodes).to be_empty
      end

      it "requires word boundary before @" do
        result = scanner.scan("email@example.com")

        expect(result.markdown).to eq("email@example.com")
        expect(result.nodes).to be_empty
      end
    end

    context "with polls" do
      it "detects polls" do
        input = "[poll type=\"regular\"]\n* A\n* B\n[/poll]"
        result = scanner.scan(input)

        expect(result.markdown).to eq("<<POLL:0:poll>>")
        expect(result.nodes.size).to eq(1)
        expect(result.nodes.first).to be_a(Markbridge::AST::Poll)
        expect(result.nodes.first.type).to eq("regular")
      end

      it "extracts poll options" do
        input = "[poll]\n* Option A\n* Option B\n* Option C\n[/poll]"
        result = scanner.scan(input)

        expect(result.nodes.first.options).to eq(["Option A", "Option B", "Option C"])
      end

      it "skips polls in fenced code blocks" do
        input = "```\n[poll]\n* A\n[/poll]\n```"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end
    end

    context "with events" do
      it "detects events" do
        input = '[event name="Meeting" start="2025-12-15 14:00"][/event]'
        result = scanner.scan(input)

        expect(result.markdown).to eq("<<EVENT:0:Meeting>>")
        expect(result.nodes.size).to eq(1)
        expect(result.nodes.first).to be_a(Markbridge::AST::Event)
        expect(result.nodes.first.name).to eq("Meeting")
        expect(result.nodes.first.starts_at).to eq("2025-12-15 14:00")
      end

      it "extracts all event attributes" do
        input =
          '[event name="Conf" start="2025-12-15" end="2025-12-16" status="public" timezone="UTC"][/event]'
        result = scanner.scan(input)

        event = result.nodes.first
        expect(event.name).to eq("Conf")
        expect(event.ends_at).to eq("2025-12-16")
        expect(event.status).to eq("public")
        expect(event.timezone).to eq("UTC")
      end
    end

    context "with uploads" do
      it "detects image uploads" do
        input = "![alt|64x64](upload://abc123.png)"
        result = scanner.scan(input)

        expect(result.markdown).to eq("<<UPLOAD:0:abc123>>")
        expect(result.nodes.size).to eq(1)
        expect(result.nodes.first).to be_a(Markbridge::AST::Upload)
        expect(result.nodes.first.type).to eq(:image)
        expect(result.nodes.first.sha1).to eq("abc123")
      end

      it "detects attachment uploads" do
        input = "[doc.pdf|attachment](upload://xyz789.pdf) (1.2 MB)"
        result = scanner.scan(input)

        expect(result.markdown).to eq("<<UPLOAD:0:xyz789>>")
        expect(result.nodes.first.type).to eq(:attachment)
        expect(result.nodes.first.filename).to eq("doc.pdf")
      end

      it "skips uploads in fenced code blocks" do
        input = "```\n![img](upload://abc.png)\n```"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end
    end

    context "with mixed constructs" do
      it "handles multiple construct types" do
        input = <<~MD
          Hello @user!

          [poll]
          * Yes
          * No
          [/poll]

          ![img](upload://abc.png)
        MD

        result = scanner.scan(input)

        expect(result.nodes.size).to eq(3)
        expect(result.nodes[0]).to be_a(Markbridge::AST::Mention)
        expect(result.nodes[1]).to be_a(Markbridge::AST::Poll)
        expect(result.nodes[2]).to be_a(Markbridge::AST::Upload)
      end
    end

    context "with indented fenced code blocks" do
      it "handles 1-space indented fence" do
        input = " ```\n@gerhard\n ```"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end

      it "handles 3-space indented fence" do
        input = "   ```\n@gerhard\n   ```"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end
    end

    context "with 4-space indented code blocks" do
      it "skips mentions in indented code blocks" do
        input = "    @gerhard"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end

      it "skips polls in indented code blocks" do
        input = "    [poll]\n    * A\n    [/poll]"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end

      it "skips uploads in indented code blocks" do
        input = "    ![img](upload://abc.png)"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end

      it "handles multi-line indented code blocks" do
        input = "    line 1 @mention\n    line 2 @another\n    line 3"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end

      it "handles indented code block with blank line" do
        input = "    code @mention\n\n    more code"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end

      it "detects mentions after indented code block ends" do
        input = "    code block\nnormal text @gerhard"
        result = scanner.scan(input)

        expect(result.nodes.size).to eq(1)
        expect(result.nodes.first.name).to eq("gerhard")
      end

      it "handles tab-indented code blocks" do
        input = "\t@gerhard"
        result = scanner.scan(input)

        expect(result.markdown).to eq(input)
        expect(result.nodes).to be_empty
      end

      it "does not treat 3 spaces as code block" do
        input = "   @gerhard"
        result = scanner.scan(input)

        expect(result.nodes.size).to eq(1)
        expect(result.nodes.first.name).to eq("gerhard")
      end
    end
  end
end
