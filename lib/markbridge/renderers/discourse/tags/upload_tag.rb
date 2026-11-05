# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Placeholder tag for rendering Discourse uploads.
        #
        # This is a STUB implementation that outputs the original raw Markdown.
        # Applications using Markbridge should provide their own custom tag
        # to render uploads as placeholders or resolve upload:// URLs.
        #
        # @example Custom renderer with placeholder
        #   # An upload is inline, so the placeholder token says what the
        #   # importer will put there (see "Placeholders" in the migration
        #   # guide): the renderer joins it with its neighbors like that.
        #   Tokens = Markbridge::Renderers::Discourse::Inline::Tokens
        #
        #   class MyUploadTag < Markbridge::Renderers::Discourse::Tags::UploadTag
        #     def render(element, interface)
        #       like = "![image](upload://#{element.sha1})"
        #       [Tokens.placeholder("<<UPLOAD:#{element.sha1}>>", like:)]
        #     end
        #   end
        #
        # @example Custom renderer that resolves URLs
        #   class MyUploadTag < Markbridge::Renderers::Discourse::Tags::UploadTag
        #     def render(element, interface)
        #       url = resolve_upload(element.sha1)
        #       if element.type == :image
        #         "![#{element.alt}](#{url})"
        #       else
        #         "[#{element.filename}](#{url})"
        #       end
        #     end
        #   end
        class UploadTag < Tag
          # An upload is always written in one of Discourse's Markdown
          # forms, through RenderingInterface#markdown_island: Discourse
          # reads the dimensions and the `attachment` marker only from the
          # Markdown, and its sanitizer drops the `upload://` href of a
          # raw HTML link.
          def render(element, interface)
            interface.markdown_island(build_upload_markdown(element, interface), block: false)
          end

          private

          def build_upload_markdown(element, interface)
            return raw(element, interface) if element.raw

            if element.type == :image
              build_image_markdown(element, interface)
            else
              build_attachment_markdown(element, interface)
            end
          end

          # The raw Markdown of the source, with the pipes escaped in a
          # table cell. One that is escaped already stays as it is.
          def raw(element, interface)
            return element.raw unless markdown_cell?(interface)

            element.raw.gsub(/(?<!\\)\|/, "\\\\|")
          end

          # A `|` ends the cell of a Markdown table. Discourse keeps the
          # pipes inside a link or an image since August 2026, plain
          # markdown-it and older Discourse versions do not, and `\|` works
          # in all of them: Discourse reads the dimensions and the attachment
          # marker all the same.
          def pipe(interface)
            markdown_cell?(interface) ? "\\|" : "|"
          end

          # The cell of a table written in Markdown. Inside a table written
          # as HTML the island is a paragraph of its own, where a pipe ends
          # nothing.
          def markdown_cell?(interface)
            interface.has_parent?(AST::TableCell) && !interface.html_mode?
          end

          def build_image_markdown(element, interface)
            alt = build_alt(element, interface)
            url = destination(element)

            "![#{alt}](#{url})"
          end

          def build_attachment_markdown(element, interface)
            filename = label(element.filename || "attachment", element, interface)
            url = destination(element)
            size_part = " (#{element.size})" if element.size

            "[#{filename}#{pipe(interface)}attachment](#{url})#{size_part}"
          end

          # The alt text is escaped for a link label, the dimensions are
          # ours and stay as they are.
          def build_alt(element, interface)
            parts = []
            parts << label(element.alt, element, interface) if element.alt
            parts << element.dimensions if element.dimensions

            parts.join(pipe(interface))
          end

          # Text inside the brackets goes through the renderer like any
          # text, so a `]` or Markdown in it is escaped. The label is
          # Markdown inside an HTML table as well, so html_mode is off for
          # it there.
          def label(text, element, interface)
            context = interface.with_html_mode(false).with_parent(element)
            interface.render_node(AST::Text.new(text), context:)
          end

          # The destination gets the same treatment as the one of a link:
          # a file name with a space or a parenthesis would end it early.
          def destination(element)
            LinkDestination.escape(build_upload_url(element))
          end

          def build_upload_url(element)
            filename = element.filename || element.sha1
            "upload://#{filename}"
          end
        end
      end
    end
  end
end
