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
        #   class MyUploadTag < Markbridge::Renderers::Discourse::Tags::UploadTag
        #     def render(element, interface)
        #       "<<UPLOAD:#{element.sha1}>>"
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
          def html_mode_aware? = true

          def render(element, interface)
            return build_upload_html(element) if interface.html_mode?

            # Return raw Markdown if available, otherwise reconstruct
            return element.raw if element.raw

            build_upload_markdown(element)
          end

          private

          def build_upload_markdown(element)
            if element.type == :image
              build_image_markdown(element)
            else
              build_attachment_markdown(element)
            end
          end

          def build_image_markdown(element)
            alt = build_alt(element)
            url = build_upload_url(element)

            "![#{alt}](#{url})"
          end

          def build_attachment_markdown(element)
            filename = element.filename || "attachment"
            url = build_upload_url(element)
            size_part = " (#{element.size})" if element.size

            "[#{filename}|attachment](#{url})#{size_part}"
          end

          def build_alt(element)
            parts = []
            parts << element.alt if element.alt
            parts << element.dimensions if element.dimensions

            parts.join("|")
          end

          def build_upload_url(element)
            filename = element.filename || element.sha1
            "upload://#{filename}"
          end

          # html_mode reconstructs from the AST fields rather than reusing
          # element.raw — raw is Markdown, which CommonMark passes through
          # unchanged inside an HTML block (so the user would see the
          # literal "![…](upload://…)" string instead of an image).
          def build_upload_html(element)
            if element.type == :image
              build_image_html(element)
            else
              build_attachment_html(element)
            end
          end

          def build_image_html(element)
            src = HtmlEscaper.escape(build_upload_url(element))
            alt = HtmlEscaper.escape(element.alt)
            %(<img src="#{src}" alt="#{alt}">)
          end

          def build_attachment_html(element)
            href = HtmlEscaper.escape(build_upload_url(element))
            filename = HtmlEscaper.escape(element.filename || "attachment")
            size_part = " (#{HtmlEscaper.escape(element.size)})" if element.size
            %(<a href="#{href}">#{filename}</a>#{size_part})
          end
        end
      end
    end
  end
end
