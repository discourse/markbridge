# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Placeholder tag for rendering attachments.
        #
        # This is a STUB implementation that outputs metadata as a comment.
        # Applications using Markbridge should provide their own custom renderer
        # that maps attachment IDs/indices to actual upload URLs.
        #
        # @example Custom renderer
        #   class MyAttachmentTag < Markbridge::Renderers::Discourse::Tags::AttachmentTag
        #     def render(element, interface)
        #       url = lookup_attachment_url(element.id || element.index)
        #       alt = element.alt || element.filename || ""
        #       "![#{alt}](#{url})"
        #     end
        #   end
        #
        #   library = Markbridge::Renderers::Discourse::TagLibrary.default
        #   library.register(Markbridge::AST::Attachment, MyAttachmentTag.new)
        class AttachmentTag < Tag
          def render(element, _interface)
            # Build metadata comment for downstream processing
            metadata = build_metadata(element)
            "<!-- ATTACHMENT: #{metadata} -->"
          end

          private

          def build_metadata(element)
            parts = []
            parts << "id=#{element.id}" if element.id
            parts << "index=#{element.index}" if element.index
            parts << "filename=#{element.filename}" if element.filename
            parts << "alt=#{element.alt}" if element.alt

            parts.empty? ? "UNIDENTIFIED" : parts.join(" ")
          end
        end
      end
    end
  end
end
