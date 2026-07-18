# frozen_string_literal: true

# End-to-end: the default normalization runs between parse and render, so
# these assertions show the raw Markdown you get. The default fixes legality
# (a link inside a link, a block inside an inline container). Discourse policy
# like moving an image out of a link is a rule the consumer adds.
RSpec.describe "Markbridge normalization (end-to-end)" do
  def convert(input, **kwargs) = Markbridge.convert(input, format: :bbcode, **kwargs)

  describe "default: a link inside a link" do
    let(:input) { "[url=https://a.com][url=https://b.com]click[/url][/url]" }

    it "collapses to a single link and reports it" do
      conv = convert(input)

      expect(conv.markdown).to eq("[click](https://a.com)")
      expect(conv.diagnostics[:normalization]).to contain_exactly(
        { parent: "Url", child: "Url", strategy: :unwrap, count: 1 },
      )
    end

    it "leaves the tree alone when normalize: false" do
      expect(convert(input, normalize: false).diagnostics[:normalization]).to be_nil
    end
  end

  describe "an image inside a link" do
    let(:input) { "[url=https://ex.com][img]https://ex.com/i.png[/img][/url]" }

    it "is left as a linked image by default (not a default rule)" do
      expect(convert(input).markdown).to eq("[![](https://ex.com/i.png)](https://ex.com)")
      expect(convert(input).diagnostics[:normalization]).to be_nil
    end

    it "is hoisted out by a consumer rule (how migrations-tooling does it)" do
      normalizer = Markbridge::Normalizer.default
      normalizer.rule(
        parent: Markbridge::AST::Url,
        child: Markbridge::AST::Image,
        strategy: :hoist_after,
      )

      conv = convert(input, normalize: normalizer)
      expect(conv.markdown).not_to include("[![") # not a linked image
      expect(conv.markdown).to include("![](https://ex.com/i.png)")
      expect(conv.diagnostics[:normalization]).to contain_exactly(
        { parent: "Url", child: "Image", strategy: :hoist_after, count: 1 },
      )
    end
  end

  describe "clean content" do
    it "is untouched and reports nothing" do
      conv = convert("[b]hello[/b] and [i]world[/i]")

      expect(conv.markdown).to eq("**hello** and *world*")
      expect(conv.diagnostics[:normalization]).to be_nil
    end
  end

  describe "validation property: the default leaves no default violation" do
    inputs = [
      "[url=https://a.com][url=https://b.com]x[/url][/url]",
      "plain text with [b]bold[/b] and a [url=https://ex.com]link[/url]",
      "[quote]a quote[/quote] then [url=https://ex.com]link[/url]",
    ]

    inputs.each do |input|
      it "leaves no violation for #{input.inspect}" do
        ast = Markbridge.parse_bbcode(input).ast
        Markbridge::Normalizer.shared_default.normalize(ast)

        expect(Markbridge::Normalizer.default.violations(ast)).to eq([])
      end
    end
  end
end
