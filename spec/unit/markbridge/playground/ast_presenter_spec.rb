# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../playground/ast_presenter"

RSpec.describe Markbridge::Playground::ASTPresenter do
  it "renders a readable tree with attributes" do
    quote = Markbridge::AST::Quote.new(author: "Alice")
    bold = Markbridge::AST::Bold.new
    bold << Markbridge::AST::Text.new("Hello")
    quote << bold

    result = described_class.new(quote).render

    expect(result).to include('Quote author="Alice"')
    expect(result).to include("Bold")
    expect(result).to include("Text")
  end

  it "serializes nodes for the interactive tree" do
    bold = Markbridge::AST::Bold.new
    bold << Markbridge::AST::Text.new("Hello playground")

    result = described_class.new(bold).as_json

    expect(result[:type]).to eq("Bold")
    expect(result[:category]).to eq("formatting")
    expect(result[:children].first[:type]).to eq("Text")
    expect(result[:children].first[:preview]).to eq("Hello playground")
  end

  def ast_node_names
    Markbridge::AST
      .constants
      .map { |c| Markbridge::AST.const_get(c) }
      .select { |c| c.is_a?(Class) && c < Markbridge::AST::Node }
      .reject { |c| c == Markbridge::AST::Element }
      .map { |c| c.name.split("::").last }
  end

  it "has a category mapping for every AST node type" do
    mapped = described_class::CATEGORY_MAP.keys

    ast_node_names.each do |name|
      expect(mapped).to include(name), "CATEGORY_MAP is missing #{name}"
    end
  end

  it "has an icon mapping for every AST node type" do
    mapped = described_class::ICON_MAP.keys

    ast_node_names.each { |name| expect(mapped).to include(name), "ICON_MAP is missing #{name}" }
  end

  it "computes aggregate stats" do
    document = Markbridge::AST::Document.new
    document << Markbridge::AST::Text.new("Hello")
    document << Markbridge::AST::Bold.new

    result = described_class.new(document).stats

    expect(result[:node_count]).to eq(3)
    expect(result[:element_count]).to eq(2)
    expect(result[:text_node_count]).to eq(1)
    expect(result[:max_depth]).to eq(1)
  end
end
