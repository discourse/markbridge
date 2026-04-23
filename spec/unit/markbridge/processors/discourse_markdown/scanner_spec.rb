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

    it "resets per-scan state between calls on the same instance" do
      scanner.scan("@alice and @bob")
      result = scanner.scan("@carol")

      # Placeholder indexes restart at 0 on each scan
      expect(result.markdown).to eq("<<MENTION:0:carol>>")
      expect(result.nodes.size).to eq(1)
    end

    it "produces the same result for repeated scans as for a fresh scanner" do
      input = "```\n@gerhard\n```"

      # Prime the scanner with unrelated input that leaves internal state dirty
      scanner.scan("text without newline")
      primed_result = scanner.scan(input)

      fresh_result = described_class.new.scan(input)

      expect(primed_result.markdown).to eq(fresh_result.markdown)
      expect(primed_result.nodes).to eq(fresh_result.nodes)
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

      # Kills `build_detectors(detectors, mention_resolver)` →
      # `build_detectors(detectors, nil)` mutation. Without the
      # resolver, all mentions resolve to :user; the resolver's
      # return value (here :group for "Staff") must flow through.
      it "honors mention_resolver for type classification" do
        resolver = ->(name) { name == "Staff" ? :group : :user }
        scanner_with_resolver = described_class.new(mention_resolver: resolver)

        result = scanner_with_resolver.scan("@Staff and @alice")

        expect(result.nodes.size).to eq(2)
        expect(result.nodes[0].type).to eq(:group)
        expect(result.nodes[1].type).to eq(:user)
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

    context "with a custom tag_library" do
      it "renders detected nodes via the library's tag when one is registered" do
        library = Markbridge::Renderers::Discourse::TagLibrary.new
        fixed_tag =
          Class.new(Markbridge::Renderers::Discourse::Tag) do
            def render(element, _interface, **_kwargs)
              "CUSTOM(#{element.name})"
            end
          end
        library.register(Markbridge::AST::Mention, fixed_tag.new)

        scanner = described_class.new(tag_library: library)
        result = scanner.scan("Hi @gerhard!")

        expect(result.markdown).to eq("Hi CUSTOM(gerhard)!")
      end

      it "falls back to the default placeholder when the library has no tag for the node class" do
        # Library present but no registration for Mention
        library = Markbridge::Renderers::Discourse::TagLibrary.new

        scanner = described_class.new(tag_library: library)
        result = scanner.scan("Hi @gerhard!")

        expect(result.markdown).to eq("Hi <<MENTION:0:gerhard>>!")
      end
    end

    context "when a construct is followed by a fenced code block on the next line" do
      it "still detects the fenced block (line_start tracked across handle_match)" do
        input = "@gerhard\n```\n@bob\n```"
        result = scanner.scan(input)

        # Only the first mention is detected; the one inside ``` is left as text
        expect(result.nodes.size).to eq(1)
        expect(result.nodes.first.name).to eq("gerhard")
        expect(result.markdown).to eq("<<MENTION:0:gerhard>>\n```\n@bob\n```")
      end
    end

    # Kills mutations on `@line_start = @input[@pos - 1] == "\n"` in
    # handle_match. A mid-line mention must leave @line_start = false
    # so that 4+ spaces following it are NOT treated as indented code
    # (which would swallow a trailing @mention).
    context "when a construct is followed by 4+ spaces and another mention" do
      it "does not trigger indented-code detection after a mid-line match" do
        input = "@bob    @alice"
        result = scanner.scan(input)

        # Both mentions are detected because the 4 spaces after @bob
        # don't start an indented code block (prev char is "b", not "\n").
        expect(result.nodes.size).to eq(2)
        expect(result.nodes.map(&:name)).to eq(%w[bob alice])
      end
    end

    # Loop-progress guard: scan_input must advance @pos every
    # iteration. A regression where a dispatch path fails to move
    # @pos would spin forever; the guard raises ParserStuckError.
    describe "loop-progress guard" do
      it "raises ParserStuckError when a subclass override stalls the loop" do
        buggy =
          Class.new(described_class) do
            # Override handle_match to skip the @pos advance while
            # still consuming the match node; any detected construct
            # then re-enters the loop at the same position.
            define_method(:handle_match) { |_match| }
            private :handle_match
          end

        expect { buggy.new.scan("@gerhard") }.to raise_error(Markbridge::ParserStuckError)
      end

      it "resets guard state between successive scans on the same instance" do
        instance = described_class.new
        instance.scan("first pass")

        # Without reset, @last_progress_pos from the prior scan would
        # cause the first progressed!(0) of the second scan to raise.
        expect { instance.scan("second pass") }.not_to raise_error
      end
    end
  end
end
