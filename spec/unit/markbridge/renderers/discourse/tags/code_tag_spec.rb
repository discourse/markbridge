# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::CodeTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders inline code without language" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("code")

      result = tag.render(element, interface)
      expect(result).to eq("`code`")
    end

    it "renders block code with newlines" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("line1\nline2")

      result = tag.render(element, interface)
      expect(result).to include("```")
      expect(result).to include("line1\nline2")
    end

    it "includes language in block code" do
      element = Markbridge::AST::Code.new(language: "ruby")
      element << Markbridge::AST::Text.new("puts 'hello'\nputs 'world'")

      result = tag.render(element, interface)
      expect(result).to include("```ruby")
    end

    it "uses ``` fence when code contains single backticks" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("code with `backticks`\nmore")

      result = tag.render(element, interface)
      # Single backticks only need 3-backtick fence (smarter than always using tildes)
      expect(result).to start_with("\n\n```\n")
      expect(result).to end_with("\n```\n\n")
    end

    it "uses tildes when code contains triple backticks (more efficient)" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("```\ncode block\nwith fences\n```")

      result = tag.render(element, interface)
      # Tildes (3) are more efficient than backticks (4)
      expect(result).to start_with("\n\n~~~\n")
      expect(result).to end_with("\n~~~\n\n")
    end

    it "uses tildes when code contains long backtick sequences" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("`````\ncode block\n`````")

      result = tag.render(element, interface)
      # Tildes (3) are more efficient than backticks (6)
      expect(result).to start_with("\n\n~~~\n")
      expect(result).to end_with("\n~~~\n\n")
    end

    it "uses backticks when content has long tilde sequences" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("~~~\ncode with tildes\n~~~")

      result = tag.render(element, interface)
      # Backticks (3) are more efficient than tildes (4)
      expect(result).to start_with("\n\n```\n")
      expect(result).to end_with("\n```\n\n")
    end

    it "handles content with both backticks and tildes" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("```\nand\n~~~")

      result = tag.render(element, interface)
      # Should use ~~~~ (4 tildes) since it's shorter than ```` (4 backticks)
      # Actually both are equal, so backticks win
      expect(result).to start_with("\n\n````\n")
      expect(result).to end_with("\n````\n\n")
    end

    it "uses the maximum (not first or last) backtick run length to size the fence" do
      element = Markbridge::AST::Code.new
      # Runs: 1 (first), 6 (middle), 1 (last). Only `max` produces 6.
      element << Markbridge::AST::Text.new("`a\n``````\nb`")

      result = tag.render(element, interface)
      expect(result).to start_with("\n\n~~~\n") # 7 backticks needed; tildes shorter
      expect(result).to end_with("\n~~~\n\n")
    end

    it "uses the maximum (not first or last) tilde run length to size the fence" do
      element = Markbridge::AST::Code.new
      # Runs: 1 (first), 6 (middle), 1 (last). Only `max` produces 6.
      element << Markbridge::AST::Text.new("~a\n~~~~~~\nb~")

      result = tag.render(element, interface)
      expect(result).to start_with("\n\n```\n") # 7 tildes needed; backticks shorter
      expect(result).to end_with("\n```\n\n")
    end

    it "uses an empty language tag when language is nil" do
      element = Markbridge::AST::Code.new
      element << Markbridge::AST::Text.new("a\nb")

      result = tag.render(element, interface)
      expect(result).to start_with("\n\n```\n") # No language between fence and newline
    end

    it "needs only run-length+1 tildes when tildes are shorter than backticks" do
      element = Markbridge::AST::Code.new
      # 3 backticks (need 4) and 2 tildes (need 3). 3-tilde fence wins (shorter).
      element << Markbridge::AST::Text.new("```\nand\n~~")

      result = tag.render(element, interface)
      expect(result).to start_with("\n\n~~~\n")
      expect(result).to end_with("\n~~~\n\n")
    end

    # Mixed content that exercises .max (not .min/.first/.last) on
    # BOTH scan arrays. Without .max on tildes, mutation would pick
    # min tilde length (1) and select tildes as the shorter fence,
    # but a 3-tilde fence fails against the content's 6-tilde run.
    # Similarly without .max on backticks, mutation would undersize
    # the backtick fence.
    it "uses max (not min/first/last) on both tilde and backtick run lengths" do
      element = Markbridge::AST::Code.new
      # Backtick runs: [3]. Tilde runs: [6, 1].
      # Original: required_backticks=4, required_tildes=7 → backtick fence (4).
      # .min on tildes: required_tildes=2→3 ≤ required_backticks=4 → backticks.
      #   Same selection but WRONG sizing on tildes would break if fence=tildes.
      # .max on backticks missing: required_backticks=2→3 → 3 ≤ 7 → backticks (3).
      #   Content has ``` → fence=``` fails.
      element << Markbridge::AST::Text.new("```\nand\n~~~~~~\n~")

      result = tag.render(element, interface)
      # 4-backtick fence: original backticks max=3 → fence=4.
      expect(result).to start_with("\n\n````\n")
      expect(result).to end_with("\n````\n\n")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders inline code as <code>" do
        element = Markbridge::AST::Code.new
        element << Markbridge::AST::Text.new("x")

        expect(tag.render(element, interface)).to eq("<code>x</code>")
      end

      it "HTML-escapes text content inside inline code" do
        element = Markbridge::AST::Code.new
        element << Markbridge::AST::Text.new("a < b")

        expect(tag.render(element, interface)).to eq("<code>a &lt; b</code>")
      end

      it "renders block code as <pre><code>" do
        element = Markbridge::AST::Code.new
        element << Markbridge::AST::Text.new("line1\nline2")

        expect(tag.render(element, interface)).to eq("<pre><code>line1\nline2</code></pre>")
      end

      it "adds a language class when language is set" do
        element = Markbridge::AST::Code.new(language: "ruby")
        element << Markbridge::AST::Text.new("puts 1\nputs 2")

        expect(tag.render(element, interface)).to eq(
          %(<pre><code class="language-ruby">puts 1\nputs 2</code></pre>),
        )
      end

      it "HTML-escapes block code content" do
        element = Markbridge::AST::Code.new
        element << Markbridge::AST::Text.new("a < b\n&& c")

        expect(tag.render(element, interface)).to eq(
          "<pre><code>a &lt; b\n&amp;&amp; c</code></pre>",
        )
      end

      it "HTML-escapes the language attribute" do
        element = Markbridge::AST::Code.new(language: %("><script>))
        element << Markbridge::AST::Text.new("x\ny")

        expect(tag.render(element, interface)).to eq(
          %(<pre><code class="language-&quot;&gt;&lt;script&gt;">x\ny</code></pre>),
        )
      end
    end
  end
end
