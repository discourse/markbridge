# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::PollTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "returns the raw BBCode verbatim when present" do
      element = Markbridge::AST::Poll.new(raw: "[poll]ORIGINAL[/poll]")

      expect(tag.render(element, interface)).to eq("[poll]ORIGINAL[/poll]\n\n")
    end

    it "reconstructs BBCode with options when raw is missing" do
      element = Markbridge::AST::Poll.new(options: %w[A B])

      expect(tag.render(element, interface)).to eq("[poll]\n* A\n* B\n[/poll]\n\n")
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

      expect(tag.render(element, interface)).to eq("[poll]\n\n[/poll]\n\n")
    end

    it "emits a trailing blank line after a reconstructed poll" do
      element = Markbridge::AST::Poll.new(name: "fav", type: "regular", options: %w[A B])

      expect(tag.render(element, interface)).to end_with("[/poll]\n\n")
    end

    it "emits a trailing blank line after a raw-passthrough poll" do
      element = Markbridge::AST::Poll.new(raw: "[poll]\n* A\n* B\n[/poll]")

      expect(tag.render(element, interface)).to eq("[poll]\n* A\n* B\n[/poll]\n\n")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "wraps the BBCode in leading + trailing blank lines so CommonMark re-enters Markdown parsing" do
        element = Markbridge::AST::Poll.new(options: %w[A B])

        expect(tag.render(element, interface)).to eq("\n\n[poll]\n* A\n* B\n[/poll]\n\n")
      end

      it "wraps a raw-passthrough poll in blank lines too" do
        element = Markbridge::AST::Poll.new(raw: "[poll]ORIGINAL[/poll]")

        expect(tag.render(element, interface)).to eq("\n\n[poll]ORIGINAL[/poll]\n\n")
      end
    end
  end
end
