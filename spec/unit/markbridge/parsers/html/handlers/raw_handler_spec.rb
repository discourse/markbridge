# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::RawHandler do
  let(:handler) { described_class.new(Markbridge::AST::Code) }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "creates an element of the configured class carrying the inner text" do
      handler.process(element: build_element("<code>code content</code>"), parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Code)
      expect(parent.children[0].children[0].text).to eq("code content")
    end

    it "extracts language from a language-* class" do
      handler.process(element: build_element('<code class="language-ruby">code</code>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "extracts language from a language-* class among styling classes" do
      handler.process(element: build_element('<pre class="hljs language-ruby">code</pre>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "extracts language from a language-* class on the direct code child" do
      handler.process(
        element: build_element('<pre><code class="language-python">code</code></pre>'),
        parent:,
      )

      expect(parent.children[0].language).to eq("python")
    end

    it "prefers a language-* class on the code child over a lone class on the element" do
      handler.process(
        element:
          build_element('<pre class="prettyprint"><code class="language-ruby">code</code></pre>'),
        parent:,
      )

      expect(parent.children[0].language).to eq("ruby")
    end

    it "extracts language from the lang attribute" do
      handler.process(element: build_element('<code lang="python">code</code>'), parent:)

      expect(parent.children[0].language).to eq("python")
    end

    it "strips and downcases the lang attribute" do
      handler.process(element: build_element('<code lang=" RUBY ">code</code>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "downcases a lone class on the direct code child" do
      handler.process(element: build_element('<pre><code class="Ruby">code</code></pre>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "prefers a language-* class over the lang attribute" do
      handler.process(
        element: build_element('<code class="language-ruby" lang="python">code</code>'),
        parent:,
      )

      expect(parent.children[0].language).to eq("ruby")
    end

    it "prefers the lang attribute over a lone class without language- prefix" do
      handler.process(
        element: build_element('<code class="ruby" lang="python">code</code>'),
        parent:,
      )

      expect(parent.children[0].language).to eq("python")
    end

    it "uses a lone class as language when nothing else matches" do
      handler.process(element: build_element('<code class="ruby">code</code>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "leaves language nil for multiple classes without language- prefix" do
      handler.process(element: build_element('<pre class="hljs prettyprint">code</pre>'), parent:)

      expect(parent.children[0].language).to be_nil
    end

    it "leaves language nil when the extracted token is not a valid language" do
      handler.process(element: build_element('<code class="language-c#">code</code>'), parent:)

      expect(parent.children[0].language).to be_nil
    end

    it "downcases the extracted language" do
      handler.process(element: build_element('<code class="language-Ruby">code</code>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "leaves language nil when neither attribute is present" do
      handler.process(element: build_element("<code>code</code>"), parent:)

      expect(parent.children[0].language).to be_nil
    end

    it "sets block on the element for pre" do
      handler.process(element: build_element("<pre>x</pre>"), parent:)

      expect(parent.children[0].block).to be true
    end

    it "leaves block nil for code" do
      handler.process(element: build_element("<code>x</code>"), parent:)

      expect(parent.children[0].block).to be_nil
    end

    it "leaves block nil for tt" do
      handler.process(element: build_element("<tt>x</tt>"), parent:)

      expect(parent.children[0].block).to be_nil
    end

    it "does not append a Text child when the inner text is empty" do
      handler.process(element: build_element("<code></code>"), parent:)

      expect(parent.children[0].children).to be_empty
    end

    it "preserves whitespace in the inner text" do
      handler.process(element: build_element("<code>  line 1\n  line 2  </code>"), parent:)

      expect(parent.children[0].children[0].text).to eq("  line 1\n  line 2  ")
    end

    it "returns nil to signal children should not be processed" do
      result = handler.process(element: build_element("<code>code</code>"), parent:)

      expect(result).to be_nil
    end
  end

  describe "#element_class" do
    it "returns the element class it was initialized with" do
      expect(handler.element_class).to eq(Markbridge::AST::Code)
    end
  end
end
