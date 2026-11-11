# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::BaseUrl do
  subject(:base) { described_class.new("https://wiki.example.com/wiki/Main_Page?x=1#y") }

  describe "#initialize" do
    it "takes an http or https URL, in any case" do
      expect(described_class.new("HTTP://Example.com").resolve("a")).to eq("HTTP://Example.com/a")
    end

    it "takes a URL with a query or a fragment, also an empty one" do
      %w[
        https://e.org/a/b?x=1
        https://e.org/a/b#y
        https://e.org/a/b?
        https://e.org/a/b#
      ].each { |url| expect(described_class.new(url).resolve("c")).to eq("https://e.org/a/c") }
    end

    it "raises for a URL with whitespace in it or after it" do
      [
        "https://example.com/my forum/",
        "https://example.com/a?x y",
        "https://example.com/a#x y",
        "https://example.com/a\n",
        "https://example.com/a ",
      ].each do |url|
        expect { described_class.new(url) }.to raise_error(
          ArgumentError,
          "base_url must be an http or https URL, got #{url.inspect}",
        )
      end
    end

    it "raises for what is no http or https URL" do
      ["ftp://example.com", "example.com", "/wiki/", "", nil, " https://example.com"].each do |url|
        expect { described_class.new(url) }.to raise_error(
          ArgumentError,
          "base_url must be an http or https URL, got #{url.inspect}",
        )
      end
    end
  end

  describe "#resolve" do
    it "leaves an address with a scheme alone" do
      %w[
        https://e.org/a
        HTTP://e.org
        mailto:a@b.c
        ftp://e.org
        x-app+1.2:y
        Help:Contents
      ].each { |address| expect(base.resolve(address)).to eq(address) }
    end

    it "leaves nil, an empty address, a fragment and a protocol-relative address alone" do
      [nil, "", "#top", "//cdn.example.com/a"].each do |address|
        expect(base.resolve(address)).to eq(address)
      end
    end

    it "puts the origin in front of a path with a leading slash" do
      expect(base.resolve("/files/a.png")).to eq("https://wiki.example.com/files/a.png")
    end

    it "puts the page of the base in front of a query" do
      expect(base.resolve("?action=edit")).to eq(
        "https://wiki.example.com/wiki/Main_Page?action=edit",
      )
    end

    it "puts the directory of the base in front of a relative path" do
      expect(base.resolve("Alta_Via")).to eq("https://wiki.example.com/wiki/Alta_Via")
      expect(base.resolve("a/b c")).to eq("https://wiki.example.com/wiki/a/b c")
    end

    it "takes a base that ends with a slash as a directory" do
      directory = described_class.new("https://example.com/forum/")

      expect(directory.resolve("a")).to eq("https://example.com/forum/a")
    end

    it "takes a base without a path as the root" do
      root = described_class.new("https://example.com")

      expect(root.resolve("a")).to eq("https://example.com/a")
      expect(root.resolve("?q=1")).to eq("https://example.com/?q=1")
    end

    it "resolves the dot segments of the path" do
      {
        "./Alta_Via" => "/wiki/Alta_Via",
        "../files/a.png" => "/files/a.png",
        "a/./b/../c" => "/wiki/a/c",
        "a/b/../../c" => "/wiki/c",
        "." => "/wiki/",
        ".." => "/",
        "x/.." => "/wiki/",
        "x/." => "/wiki/x/",
        "../../.." => "/",
        "a/..b/.c" => "/wiki/a/..b/.c",
        "dir/" => "/wiki/dir/",
        "../../a" => "/a",
        "../../../a/b" => "/a/b",
      }.each do |address, path|
        expect(base.resolve(address)).to eq("https://wiki.example.com#{path}"), address
      end
    end

    it "leaves the dots of a query and of a fragment alone" do
      expect(base.resolve("a?b=../c")).to eq("https://wiki.example.com/wiki/a?b=../c")
      expect(base.resolve("./a#../b")).to eq("https://wiki.example.com/wiki/a#../b")
      expect(base.resolve("a/../b?c=1#d?e")).to eq("https://wiki.example.com/wiki/b?c=1#d?e")
      expect(base.resolve("a?b=x/../c")).to eq("https://wiki.example.com/wiki/a?b=x/../c")
      expect(base.resolve("a#x/./c")).to eq("https://wiki.example.com/wiki/a#x/./c")
    end
  end
end
