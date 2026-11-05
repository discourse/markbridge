# frozen_string_literal: true

# The tools of the round-trip specs, checked on their own: with the
# known-bug lists empty, nothing else shows that a check can fail, that
# a case is found by its id, or that a failing tree shrinks.
RSpec.describe "the round-trip support" do
  AST = Markbridge::AST

  def text(string)
    AST::Text.new(string)
  end

  describe AstGenerator do
    it "builds the same document for the same seed, and another one for another seed" do
      expect(AstDump.dump(AstGenerator.new(7).document)).to eq(
        AstDump.dump(AstGenerator.new(7).document),
      )
      expect(AstDump.dump(AstGenerator.new(7).document)).not_to eq(
        AstDump.dump(AstGenerator.new(8).document),
      )
    end
  end

  describe AdjacencyGenerator do
    it "finds the cases of a sample and the block cases by their ids" do
      cases = AdjacencyGenerator.inline_sample(50, seed: 3) + AdjacencyGenerator.block_cases

      expect(cases.map { |kase| AdjacencyGenerator.find(kase.id)&.id }).to eq(cases.map(&:id))
    end

    it "finds no case for an id it does not build" do
      expect(AdjacencyGenerator.find("paragraph/nothing+bold(a)")).to be_nil
      expect(AdjacencyGenerator.find("nowhere/text(a)+bold(a)")).to be_nil
      expect(AdjacencyGenerator.find("blocks/nowhere")).to be_nil
    end

    it "knows how many inline cases there are" do
      expect(AdjacencyGenerator.inline_cases.size).to eq(AdjacencyGenerator.inline_size)
    end
  end

  describe RoundTripChecker do
    subject(:checker) { described_class.new }

    def checks(document)
      checker.failures(document).map(&:check)
    end

    it "reports a tree the normalizer would rewrite, without cooking" do
      inner = AST::Url.new(href: "https://b.example") << text("x")
      document = AST::Document.new << (AST::Url.new(href: "https://a.example") << inner)

      expect(checks(document)).to eq([:normalizer])
    end

    it "reports a node that is not where it belongs, without cooking" do
      document = AST::Document.new << (AST::ListItem.new << text("x"))

      expect(checks(document)).to eq([:shape])
    end

    context "with the HTML markdown-it cooks" do
      def cooked(document, html)
        allow(MarkdownItCooker).to receive(:cook).and_return(html)
        checks(document)
      end

      it "passes a document whose cooked HTML says what the AST says" do
        expect(cooked(AST::Document.new << text("x"), "<p>x</p>")).to eq([])
      end

      it "reports the structure when an element is missing" do
        document = AST::Document.new << (AST::Bold.new << text("x"))

        expect(cooked(document, "<p>x</p>")).to eq([:structure])
      end

      it "reports the text when it differs" do
        expect(cooked(AST::Document.new << text("x"), "<p>y</p>")).to eq([:text])
      end

      it "reports the links when a link is missing" do
        link = AST::Url.new(href: "https://example.com/") << text("t")
        document = AST::Document.new << link

        expect(cooked(document, "<p>t</p>")).to eq(%i[structure links])
      end

      it "reports a list that cooks loose" do
        document = AST::Document.new << (AST::List.new << (AST::ListItem.new << text("a")))

        expect(cooked(document, "<ul>\n<li>\n<p>a</p>\n</li>\n</ul>")).to eq([:lists])
      end
    end
  end

  describe AstShrinker do
    it "shrinks a document to the nodes the failure needs" do
      paragraph = AST::Paragraph.new << text("hello") << (AST::Bold.new << text("world"))
      list = AST::List.new << (AST::ListItem.new << text("x"))
      document = AST::Document.new << paragraph << list

      AstShrinker.shrink(document) { |candidate| candidate.descendants.any?(AST::Bold) }

      expect(AstDump.dump(document)).to eq("Document\n  Bold")
    end
  end

  describe AstDump do
    it "prints one node per line, indented" do
      document = AST::Document.new << (AST::Bold.new << text("x"))

      expect(AstDump.dump(document)).to eq("Document\n  Bold\n    Text \"x\"")
    end

    it "reduces the texts to their character classes for the signature" do
      document = AST::Document.new << text("alice 42, bob!")

      expect(AstDump.signature(document)).to eq("Document\n  Text \"a 1, a!\"")
    end
  end
end
