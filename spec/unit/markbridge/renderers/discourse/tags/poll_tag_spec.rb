# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::PollTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "returns the raw BBCode verbatim when present, as a standalone block" do
      element = Markbridge::AST::Poll.new(raw: "[poll]ORIGINAL[/poll]")

      expect(tag.render(element, interface)).to eq("\n\n[poll]ORIGINAL[/poll]\n\n")
    end

    it "reconstructs BBCode with options when raw is missing" do
      element = Markbridge::AST::Poll.new(options: %w[A B])

      expect(tag.render(element, interface)).to eq("\n\n[poll]\n* A\n* B\n[/poll]\n\n")
    end

    it "omits the name attribute when it equals the default 'poll'" do
      element = Markbridge::AST::Poll.new(name: "poll", options: %w[A])

      expect(tag.render(element, interface)).not_to include("name=")
    end

    it "omits the name attribute when name is nil" do
      element = Markbridge::AST::Poll.new(name: nil, options: %w[A])

      expect(tag.render(element, interface)).not_to include("name=")
    end

    it "includes a custom name attribute" do
      element = Markbridge::AST::Poll.new(name: "favorite", options: %w[A])

      expect(tag.render(element, interface)).to include('name="favorite"')
    end

    it "includes the type attribute when present" do
      element = Markbridge::AST::Poll.new(type: "multiple", options: %w[A])

      expect(tag.render(element, interface)).to include('type="multiple"')
    end

    it "includes the results attribute when present" do
      element = Markbridge::AST::Poll.new(results: "on_vote", options: %w[A])

      expect(tag.render(element, interface)).to include('results="on_vote"')
    end

    it "includes public=true when public is set" do
      element = Markbridge::AST::Poll.new(public: true, options: %w[A])

      expect(tag.render(element, interface)).to include('public="true"')
    end

    it "omits public attribute when public is false (the default)" do
      element = Markbridge::AST::Poll.new(options: %w[A])

      expect(tag.render(element, interface)).not_to include("public=")
    end

    it "includes the chartType attribute when chart_type is set" do
      element = Markbridge::AST::Poll.new(chart_type: "bar", options: %w[A])

      expect(tag.render(element, interface)).to include('chartType="bar"')
    end

    it "produces an empty options block when there are no options" do
      element = Markbridge::AST::Poll.new

      expect(tag.render(element, interface)).to eq("\n\n[poll]\n\n[/poll]\n\n")
    end

    it "brackets a reconstructed poll with leading and trailing blank lines" do
      element = Markbridge::AST::Poll.new(name: "fav", type: "regular", options: %w[A B])

      expect(tag.render(element, interface)).to start_with("\n\n[poll")
      expect(tag.render(element, interface)).to end_with("[/poll]\n\n")
    end

    it "brackets a raw-passthrough poll the same way" do
      element = Markbridge::AST::Poll.new(raw: "[poll]\n* A\n* B\n[/poll]")

      expect(tag.render(element, interface)).to eq("\n\n[poll]\n* A\n* B\n[/poll]\n\n")
    end

    # The stub is mode-agnostic: the same blank-line-bracketed island serves
    # both a standalone block in Markdown and the html_mode contract (which
    # is enforced by html_mode_contract_spec).
    it "emits the same island form in html_mode" do
      html_context = Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true)
      html_interface =
        Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, html_context)
      element = Markbridge::AST::Poll.new(options: %w[A B])

      expect(tag.render(element, html_interface)).to eq("\n\n[poll]\n* A\n* B\n[/poll]\n\n")
    end
  end

  context "with bbcode: false" do
    let(:tag) { described_class.new(bbcode: false) }

    it "writes the options as a bullet list" do
      element = Markbridge::AST::Poll.new(name: "fav", options: %w[A *B*])

      expect(tag.render(element, interface)).to eq("\n\n- A\n- \\*B\\*\n\n\n")
    end

    it "writes a bullet list in html_mode" do
      element = Markbridge::AST::Poll.new(options: %w[A B])

      expect(tag.render(element, interface_for(html_mode: true))).to eq(
        "<ul><li>A</li><li>B</li></ul>",
      )
    end

    it "renders a poll without options to nothing, also with raw BBCode" do
      element = Markbridge::AST::Poll.new(raw: "[poll]ORIGINAL[/poll]")

      expect(tag.render(element, interface)).to eq("")
    end

    it "starts and ends with a bullet list" do
      element = Markbridge::AST::Poll.new(options: %w[A])

      expect(tag.leading_list(element, interface)).to be_a(Markbridge::AST::List).and(
        have_attributes(ordered?: false),
      )
      expect(tag.trailing_list(element, interface)).to be_a(Markbridge::AST::List).and(
        have_attributes(ordered?: false),
      )
    end

    context "with a list in front" do
      let(:element) { Markbridge::AST::Poll.new(options: %w[A B]) }

      # The list of the options asks too, and gets the real answer.
      def list_in_front(ordered:)
        allow(renderer).to receive(:previous_list).and_call_original
        allow(renderer).to receive(:previous_list).with(element).and_return(
          Markbridge::AST::List.new(ordered:),
        )
      end

      it "puts the separator in front of the options after a bullet list" do
        list_in_front(ordered: false)

        expect(tag.render(element, interface)).to eq("\n\n<!---->\n\n\n\n- A\n- B\n\n\n")
      end

      it "writes the options as they are after an ordered list" do
        list_in_front(ordered: true)

        expect(tag.render(element, interface)).to eq("\n\n- A\n- B\n\n\n")
      end

      context "without options" do
        let(:element) { Markbridge::AST::Poll.new }

        it "renders to nothing" do
          list_in_front(ordered: false)

          expect(tag.render(element, interface)).to eq("")
        end
      end
    end
  end

  describe "#leading_list and #trailing_list" do
    it "are nil with the plugin, the BBCode lines are the edges" do
      element = Markbridge::AST::Poll.new(options: %w[A])

      expect(tag.leading_list(element, interface)).to be_nil
      expect(tag.trailing_list(element, interface)).to be_nil
    end
  end
end
