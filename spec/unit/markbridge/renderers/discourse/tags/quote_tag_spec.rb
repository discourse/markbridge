# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::QuoteTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "renders plain quote as Markdown blockquote" do
      element = Markbridge::AST::Quote.new
      element << Markbridge::AST::Text.new("This is a quote")

      result = tag.render(element, interface)
      expect(result).to eq("\n\n> This is a quote\n\n")
    end

    it "renders quote with author as Discourse BBCode" do
      element = Markbridge::AST::Quote.new(author: "John")
      element << Markbridge::AST::Text.new("This is a quote")

      result = tag.render(element, interface)
      expect(result).to eq("\n\n[quote=\"John\"]\nThis is a quote\n[/quote]\n\n")
    end

    it "renders quote with full Discourse context" do
      element = Markbridge::AST::Quote.new(username: "john", post_number: 123, topic_id: 456)
      element << Markbridge::AST::Text.new("This is a quote")

      result = tag.render(element, interface)
      expect(result).to eq(
        "\n\n[quote=\"john, post:123, topic:456\"]\nThis is a quote\n[/quote]\n\n",
      )
    end

    it "renders multi-line plain quote with blockquote syntax" do
      element = Markbridge::AST::Quote.new
      element << Markbridge::AST::Text.new("Line 1\nLine 2\nLine 3")

      result = tag.render(element, interface)
      expect(result).to eq("\n\n> Line 1\n> Line 2\n> Line 3\n\n")
    end

    it "falls back to author-only form when post is missing but topic and username are set" do
      element = Markbridge::AST::Quote.new(author: "John", topic_id: 456, username: "john")
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("\n\n[quote=\"John\"]\nhi\n[/quote]\n\n")
    end

    it "falls back to author-only form when topic is missing but post and username are set" do
      element = Markbridge::AST::Quote.new(author: "John", post_number: 123, username: "john")
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("\n\n[quote=\"John\"]\nhi\n[/quote]\n\n")
    end

    it "falls back to author-only form when username is missing but post and topic are set" do
      element = Markbridge::AST::Quote.new(author: "John", post_number: 123, topic_id: 456)
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("\n\n[quote=\"John\"]\nhi\n[/quote]\n\n")
    end

    it "falls back to plain blockquote when no attribution is present" do
      element = Markbridge::AST::Quote.new(post_number: 123, topic_id: 456)
      element << Markbridge::AST::Text.new("hi")

      # post_number + topic_id without username AND without author -> plain blockquote
      expect(tag.render(element, interface)).to eq("\n\n> hi\n\n")
    end

    it "uses the username as name-only attribution when author is missing" do
      # A quote attributed by ids only (e.g. phpBB post_id/user_id) can't
      # produce a Discourse post reference, but the name must survive.
      element = Markbridge::AST::Quote.new(username: "alice", post_id: 9001, user_id: 12)
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("\n\n[quote=\"alice\"]\nhi\n[/quote]\n\n")
    end

    context "without attribution around a quote with attribution" do
      def quote(**attrs, &block)
        Markbridge::AST::Quote.new(**attrs).tap { |q| Array(block&.call).each { |c| q << c } }
      end

      def text(value)
        Markbridge::AST::Text.new(value)
      end

      it "renders as [quote] when the quote with author is a direct child" do
        element = quote { quote(author: "X") { text("in") } }

        expect(tag.render(element, interface)).to eq(
          "\n\n[quote]\n[quote=\"X\"]\nin\n[/quote]\n[/quote]\n\n",
        )
      end

      it "renders as [quote] when the quote has a username only" do
        element = quote { quote(username: "x") { text("in") } }

        expect(tag.render(element, interface)).to eq(
          "\n\n[quote]\n[quote=\"x\"]\nin\n[/quote]\n[/quote]\n\n",
        )
      end

      it "renders as [quote] when the quote with author is deeper inside" do
        list = Markbridge::AST::List.new
        item = Markbridge::AST::ListItem.new
        item << quote(author: "X") { text("in") }
        list << item
        element = quote { [text("a"), list] }

        expect(tag.render(element, interface)).to start_with("\n\n[quote]\na\n")
      end

      it "renders as [quote] around a subclass of AST::Quote with author" do
        element = quote { Class.new(Markbridge::AST::Quote).new(author: "X") << text("in") }

        expect(tag.render(element, interface)).to start_with("\n\n[quote]\n")
      end

      it "renders every quote without attribution on the way as [quote]" do
        element = quote { quote { quote(author: "X") { text("in") } } }

        expect(tag.render(element, interface)).to eq(
          "\n\n[quote]\n[quote]\n[quote=\"X\"]\nin\n[/quote]\n[/quote]\n[/quote]\n\n",
        )
      end

      it "stays a blockquote around a quote without attribution" do
        element = quote { [quote { text("in") }, text("out")] }

        expect(tag.render(element, interface)).to eq("\n\n> > in\n> \n> out\n\n")
      end

      it "stays a blockquote around a quote attributed by ids only" do
        element = quote { quote(post_id: 1, user_id: 2) { text("in") } }

        expect(tag.render(element, interface)).to eq("\n\n> > in\n\n")
      end

      it "stays a blockquote around text and line breaks" do
        element = quote { [text("a"), Markbridge::AST::LineBreak.new, text("b")] }

        expect(tag.render(element, interface)).to eq("\n\n> a\n> b\n\n")
      end
    end

    context "with a block at the start or the end" do
      it "has no blank lines at the start and the end of a blockquote" do
        element = Markbridge::AST::Quote.new
        list = Markbridge::AST::List.new
        list << (Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a"))
        element << list

        expect(tag.render(element, interface)).to eq("\n\n> - a\n\n")
      end

      it "has no blank lines at the start and the end of a quote with author" do
        element = Markbridge::AST::Quote.new(author: "A")
        element << (Markbridge::AST::Quote.new(author: "B") << Markbridge::AST::Text.new("x"))

        expect(tag.render(element, interface)).to eq(
          "\n\n[quote=\"A\"]\n[quote=\"B\"]\nx\n[/quote]\n[/quote]\n\n",
        )
      end

      it "keeps the blank lines in the middle" do
        element = Markbridge::AST::Quote.new(author: "A")
        element << Markbridge::AST::Text.new("a")
        element << (Markbridge::AST::Quote.new(author: "B") << Markbridge::AST::Text.new("x"))
        element << Markbridge::AST::Text.new("b")

        expect(tag.render(element, interface)).to eq(
          "\n\n[quote=\"A\"]\na\n\n[quote=\"B\"]\nx\n[/quote]\n\nb\n[/quote]\n\n",
        )
      end
    end

    let(:element_class) { Markbridge::AST::Quote }
    it_behaves_like "a tag that propagates parent context"

    it "renders an empty quote to a blank line, which keeps the text around it apart" do
      expect(tag.render(Markbridge::AST::Quote.new, interface)).to eq("\n\n")
    end

    it "renders an empty quote with author to a blank line" do
      expect(tag.render(Markbridge::AST::Quote.new(author: "X"), interface)).to eq("\n\n")
    end

    context "in html_mode" do
      let(:context) { html_context }

      it "renders <blockquote>" do
        element = Markbridge::AST::Quote.new
        element << Markbridge::AST::Text.new("Hi")

        expect(tag.render(element, interface)).to eq("<blockquote>Hi</blockquote>")
      end

      it "renders nothing for an empty quote, a blank line would end the HTML block" do
        expect(tag.render(Markbridge::AST::Quote.new, interface)).to eq("")
      end

      it "drops BBCode attribution in html_mode" do
        element = Markbridge::AST::Quote.new(author: "John")
        element << Markbridge::AST::Text.new("Hi")

        expect(tag.render(element, interface)).to eq("<blockquote>Hi</blockquote>")
      end
    end
  end
end
