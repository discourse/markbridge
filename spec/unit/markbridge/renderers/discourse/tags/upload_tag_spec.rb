# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UploadTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "returns the raw markdown verbatim when present" do
      element = Markbridge::AST::Upload.new(sha1: "abc", raw: "![](upload://original.png)")

      expect(tag.render(element, interface)).to eq("![](upload://original.png)")
    end

    it "leaves the pipes of the raw Markdown alone outside a table cell" do
      element = Markbridge::AST::Upload.new(sha1: "abc", raw: "![a|10x20](upload://a.png)")

      expect(tag.render(element, interface)).to eq("![a|10x20](upload://a.png)")
    end

    it "renders an image upload as ![alt](upload://filename) when type is image" do
      element =
        Markbridge::AST::Upload.new(
          sha1: "abc",
          filename: "pic.png",
          type: :image,
          alt: "A picture",
          dimensions: "100x200",
        )

      expect(tag.render(element, interface)).to eq("![A picture|100x200](upload://pic.png)")
    end

    it "escapes the alt text like a link label and keeps the dimensions" do
      element =
        Markbridge::AST::Upload.new(
          sha1: "abc",
          filename: "pic.png",
          type: :image,
          alt: "a]b *c*",
          dimensions: "100x200",
        )

      expect(tag.render(element, interface)).to eq("![a\\]b \\*c\\*|100x200](upload://pic.png)")
    end

    it "escapes the filename of an attachment like a link label" do
      element = Markbridge::AST::Upload.new(sha1: "abc", filename: "a]b_c.txt", type: :attachment)

      expect(tag.render(element, interface)).to eq("[a\\]b\\_c.txt|attachment](upload://a]b_c.txt)")
    end

    it "uses sha1 as URL filename when filename is missing" do
      element = Markbridge::AST::Upload.new(sha1: "abc123", type: :image)

      expect(tag.render(element, interface)).to eq("![](upload://abc123)")
    end

    it "omits dimensions from alt when only alt is set" do
      element = Markbridge::AST::Upload.new(sha1: "x", type: :image, alt: "just alt")

      expect(tag.render(element, interface)).to eq("![just alt](upload://x)")
    end

    it "omits alt from alt-text when only dimensions are set" do
      element = Markbridge::AST::Upload.new(sha1: "x", type: :image, dimensions: "10x10")

      expect(tag.render(element, interface)).to eq("![10x10](upload://x)")
    end

    it "renders an attachment upload as [filename|attachment](upload://filename)" do
      element = Markbridge::AST::Upload.new(sha1: "abc", filename: "doc.pdf", type: :attachment)

      expect(tag.render(element, interface)).to eq("[doc.pdf|attachment](upload://doc.pdf)")
    end

    it "appends size in parentheses when present on attachments" do
      element =
        Markbridge::AST::Upload.new(
          sha1: "abc",
          filename: "doc.pdf",
          type: :attachment,
          size: "1.2 MB",
        )

      expect(tag.render(element, interface)).to eq(
        "[doc.pdf|attachment](upload://doc.pdf) (1.2 MB)",
      )
    end

    it "uses 'attachment' as filename fallback when missing" do
      element = Markbridge::AST::Upload.new(sha1: "abc123", type: :attachment)

      expect(tag.render(element, interface)).to eq("[attachment|attachment](upload://abc123)")
    end

    it "wraps a destination with whitespace in <>, like a link destination" do
      element =
        Markbridge::AST::Upload.new(sha1: "abc", filename: "my report.pdf", type: :attachment)

      expect(tag.render(element, interface)).to eq(
        "[my report.pdf|attachment](<upload://my report.pdf>)",
      )
    end

    it "escapes a parenthesis in the destination, which would end it" do
      element = Markbridge::AST::Upload.new(sha1: "abc", filename: "a(1).png", alt: "x")

      expect(tag.render(element, interface)).to eq("![x](upload://a\\(1\\).png)")
    end

    # A link cannot hold a link: Markdown reads the inner one and leaves
    # the brackets of the outer one as text.
    context "in a link label" do
      let(:link) { Markbridge::AST::Url.new(href: "https://example.com") }

      it "writes a file attachment as its name and size" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "report.pdf",
            type: :attachment,
            size: "1 KB",
          )

        expect(tag.render(element, interface_for(link))).to eq("report.pdf (1 KB)")
      end

      it "writes the name without a size, and the word attachment without a name" do
        named = Markbridge::AST::Upload.new(sha1: "abc", filename: "a.pdf", type: :attachment)
        unnamed = Markbridge::AST::Upload.new(sha1: "abc", filename: nil, type: :attachment)

        expect(tag.render(named, interface_for(link))).to eq("a.pdf")
        expect(tag.render(unnamed, interface_for(link))).to eq("attachment")
      end

      it "escapes the name like a link label" do
        element = Markbridge::AST::Upload.new(sha1: "abc", filename: "a]b*.pdf", type: :attachment)

        expect(tag.render(element, interface_for(link))).to eq("a\\]b\\*.pdf")
      end

      it "does the same inside a mail link" do
        element = Markbridge::AST::Upload.new(sha1: "abc", filename: "a.pdf", type: :attachment)
        mail = Markbridge::AST::Email.new(address: "alice@example.com")

        expect(tag.render(element, interface_for(mail))).to eq("a.pdf")
      end

      it "writes the name as HTML text in html_mode, no island" do
        element = Markbridge::AST::Upload.new(sha1: "abc", filename: "a<b.pdf", type: :attachment)

        expect(tag.render(element, interface_for(link, html_mode: true))).to eq("a&lt;b.pdf")
      end

      it "keeps the form of an image, a link label can hold an image" do
        element =
          Markbridge::AST::Upload.new(sha1: "abc", filename: "pic.png", type: :image, alt: "a")

        expect(tag.render(element, interface_for(link))).to eq("![a](upload://pic.png)")
      end

      it "keeps raw Markdown as it is" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "a.pdf",
            type: :attachment,
            raw: "[a.pdf|attachment](upload://a.pdf)",
          )

        expect(tag.render(element, interface_for(link))).to eq("[a.pdf|attachment](upload://a.pdf)")
      end
    end

    context "in a table cell" do
      let(:context) do
        Markbridge::Renderers::Discourse::RenderContext.new([Markbridge::AST::TableCell.new])
      end

      it "escapes the pipe in front of the dimensions, which would end the cell" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "pic.png",
            alt: "A",
            dimensions: "10x20",
          )

        expect(tag.render(element, interface)).to eq("![A\\|10x20](upload://pic.png)")
      end

      it "escapes the pipe in front of the attachment marker" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "a.pdf",
            type: :attachment,
            size: "1 KB",
          )

        expect(tag.render(element, interface)).to eq("[a.pdf\\|attachment](upload://a.pdf) (1 KB)")
      end

      it "escapes every pipe of the raw Markdown" do
        element = Markbridge::AST::Upload.new(sha1: "abc", raw: "![a|b|10x20](upload://a.png)")

        expect(tag.render(element, interface)).to eq("![a\\|b\\|10x20](upload://a.png)")
      end

      it "leaves a pipe of the raw Markdown alone that is escaped already" do
        element = Markbridge::AST::Upload.new(sha1: "abc", raw: "![a\\|b|10x20](upload://a.png)")

        expect(tag.render(element, interface)).to eq("![a\\|b\\|10x20](upload://a.png)")
      end
    end

    context "in html_mode" do
      let(:context) { html_context }

      # Discourse reads the dimensions and the attachment marker only
      # from its Markdown forms, and its sanitizer drops the upload://
      # href of a raw HTML link, so the upload is a Markdown island in a div.
      it "writes an image upload as a Markdown island" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "pic.png",
            type: :image,
            alt: "A picture",
            dimensions: "64x64",
          )

        expect(tag.render(element, interface)).to eq(
          "<div>\n\n![A picture|64x64](upload://pic.png)\n\n</div>",
        )
      end

      it "writes an attachment upload as a Markdown island with its size" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "doc.pdf",
            type: :attachment,
            size: "1.2 MB",
          )

        expect(tag.render(element, interface)).to eq(
          "<div>\n\n[doc.pdf|attachment](upload://doc.pdf) (1.2 MB)\n\n</div>",
        )
      end

      it "writes the raw Markdown as an island" do
        element = Markbridge::AST::Upload.new(sha1: "abc", raw: "![](upload://other.png)")

        expect(tag.render(element, interface)).to eq("<div>\n\n![](upload://other.png)\n\n</div>")
      end

      it "escapes the alt text and the filename like a link label, not like HTML" do
        image = Markbridge::AST::Upload.new(sha1: "abc", filename: "pic.png", alt: "a]b *c*")
        file = Markbridge::AST::Upload.new(sha1: "abc", filename: "a]b_c.txt", type: :attachment)

        expect(tag.render(image, interface)).to eq(
          "<div>\n\n![a\\]b \\*c\\*](upload://pic.png)\n\n</div>",
        )
        expect(tag.render(file, interface)).to eq(
          "<div>\n\n[a\\]b\\_c.txt|attachment](upload://a]b_c.txt)\n\n</div>",
        )
      end

      it "leaves the pipes alone inside the cell of a table written as HTML" do
        # The island is a paragraph of its own, no cell ends at a pipe.
        cell_interface = interface_for(Markbridge::AST::TableCell.new, html_mode: true)
        image =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "pic.png",
            alt: "A",
            dimensions: "10x20",
          )
        raw = Markbridge::AST::Upload.new(sha1: "abc", raw: "![a|10x20](upload://a.png)")

        expect(tag.render(image, cell_interface)).to eq(
          "<div>\n\n![A|10x20](upload://pic.png)\n\n</div>",
        )
        expect(tag.render(raw, cell_interface)).to eq(
          "<div>\n\n![a|10x20](upload://a.png)\n\n</div>",
        )
      end
    end
  end
end
