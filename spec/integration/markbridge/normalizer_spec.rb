# frozen_string_literal: true

# End-to-end: normalization runs by default between parse and render, so
# these assertions describe the raw Markdown a consumer actually gets. They
# double as the adoption check for migrations-tooling deleting the hoisting
# half of its custom Url tag.
RSpec.describe "Markbridge normalization (end-to-end)" do
  def convert(input, **kwargs) = Markbridge.convert(input, format: :bbcode, **kwargs)

  describe "linked image" do
    let(:input) { "[url=https://ex.com][img]https://ex.com/i.png[/img][/url]" }

    it "hoists the image out, leaving a bare link followed by the image (default on)" do
      md = convert(input).markdown
      expect(md).not_to include("[![") # not a linked image
      expect(md).to include("![](https://ex.com/i.png)")
      expect(md).to include("https://ex.com") # bare link survives
    end

    it "reports the hoist through diagnostics[:normalization]" do
      expect(convert(input).diagnostics[:normalization]).to contain_exactly(
        { parent: "Url", child: "Image", strategy: :hoist_after, count: 1 },
      )
    end

    it "reproduces the old linked-image output when normalize: false" do
      md = convert(input, normalize: false).markdown
      expect(md).to eq("[![](https://ex.com/i.png)](https://ex.com)")
      expect(convert(input, normalize: false).diagnostics[:normalization]).to be_nil
    end
  end

  describe "image nested inside formatting inside a link" do
    it "leaves a bare link then the image with no **** husk" do
      md = convert("[url=https://ex.com][b][img]https://ex.com/i.png[/img][/b][/url]").markdown
      expect(md).not_to include("****")
      expect(md).not_to include("[![")
      expect(md).to include("![](https://ex.com/i.png)")
    end
  end

  describe "nested links" do
    it "collapses to a single link carrying the inner label" do
      conv = convert("[url=https://a.com][url=https://b.com]click[/url][/url]")
      expect(conv.markdown).to eq("[click](https://a.com)")
      expect(conv.diagnostics[:normalization]).to contain_exactly(
        { parent: "Url", child: "Url", strategy: :unwrap, count: 1 },
      )
    end
  end

  describe "custom normalizer" do
    it "applies a consumer-added rule on top of the defaults" do
      normalizer = Markbridge::Normalizer.for(:discourse)
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)

      md =
        convert(
          "[url=https://ex.com]label[img]https://ex.com/i.png[/img][/url]",
          normalize: normalizer,
        ).markdown
      expect(md).to eq("[label](https://ex.com)") # image dropped, not hoisted
    end
  end

  describe "clean content" do
    it "is untouched and reports nothing" do
      conv = convert("[b]hello[/b] and [i]world[/i]")
      expect(conv.markdown).to eq("**hello** and *world*")
      expect(conv.diagnostics[:normalization]).to be_nil
    end
  end

  describe "validation property: the tree handed to the renderer is CommonMark-legal" do
    # After the default pass, no CommonMark-layer violation should remain.
    inputs = [
      "[url=https://ex.com][img]https://ex.com/i.png[/img][/url]",
      "[url=https://a.com][url=https://b.com]x[/url][/url]",
      "[url=https://ex.com][b][img]i.png[/img][/b][/url]",
      "plain text with [b]bold[/b] and a [url=https://ex.com]link[/url]",
      "[quote]a quote[/quote] then [url=https://ex.com]link[/url]",
    ]

    inputs.each do |input|
      it "leaves no CommonMark violations for #{input.inspect}" do
        ast = Markbridge.parse_bbcode(input).ast
        Markbridge::Normalizer.shared_for(:discourse).normalize(ast)
        expect(Markbridge::Normalizer.common_mark.violations(ast)).to eq([])
      end
    end
  end
end
