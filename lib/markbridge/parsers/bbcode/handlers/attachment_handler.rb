# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for ATTACH/ATTACHMENT tags across platforms (phpBB, vBulletin, XenForo, SMF mods).
        #
        # Examples:
        # - [attachment=0]image.jpg[/attachment]         # phpBB (index + filename)
        # - [ATTACH=CONFIG]1234[/ATTACH]                # vBulletin (id)
        # - [ATTACH type="full" alt="diagram"]5678[/ATTACH] # XenForo (id + alt)
        # - [attach id=2 msg=9876]                      # SMF-style self-contained attributes
        class AttachmentHandler < BaseHandler
          def initialize(collector: RawContentCollector.new)
            @collector = collector
            @element_class = AST::Attachment
          end

          def on_open(token:, context:, registry:, tokens: nil)
            content = collect_content(token:, tokens:)
            attachment = build_attachment(token:, content:)

            context.add_child(attachment)
          end

          # Closing tags are consumed during collection; if one leaks through, treat as text.
          def on_close(token:, context:, registry:, tokens: nil)
            context.add_child(AST::Text.new(token.source))
          end

          private

          def collect_content(token:, tokens:)
            return unless tokens
            return unless closing_tag_ahead?(token.tag, tokens)

            @collector.collect(token.tag, tokens).content
          end

          CLOSING_TAG_PEEK_DEPTH = 100
          private_constant :CLOSING_TAG_PEEK_DEPTH

          def closing_tag_ahead?(tag, tokens)
            tokens
              .peek_ahead(CLOSING_TAG_PEEK_DEPTH)
              .any? { |token| token.instance_of?(TagEndToken) && token.tag == tag }
          end

          def build_attachment(token:, content:)
            attrs = normalize_attrs(token.attrs)
            option = attrs[:option]
            body = presence(content)

            id = preferred_id(attrs)
            index = preferred_index(attrs)
            filename = attrs[:filename]
            alt = attrs[:alt]

            index ||= option if numeric?(option)
            id, filename = apply_body_content(body:, id:, index:, filename:)

            AST::Attachment.new(id:, index:, filename:, alt:)
          end

          def normalize_attrs(attrs)
            attrs.transform_values { |value| presence(value) }
          end

          def apply_body_content(body:, id:, index:, filename:)
            if id.nil?
              return body, filename if index.nil?
              return body, filename if numeric?(body)
            end

            filename ||= body

            [id, filename]
          end

          def preferred_id(attrs)
            presence(attrs[:msg]) || presence(attrs[:id])
          end

          def preferred_index(attrs)
            explicit_index = presence(attrs[:index])
            smf_index = presence(attrs[:id]) if attrs[:msg]

            explicit_index || smf_index
          end

          def presence(value)
            return value unless value.instance_of?(String)

            stripped = value.strip
            stripped unless stripped.empty?
          end

          def numeric?(value)
            value.instance_of?(String) && value.match?(/\A\d+\z/)
          end
        end
      end
    end
  end
end
