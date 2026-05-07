# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Maps recognized inline `style` declarations on `<span>` to AST
        # formatting nodes. Supports text-decoration (underline,
        # line-through), font-weight (bold), and font-style (italic). When
        # multiple recognized styles are set, AST elements are nested in
        # declaration order. Unrecognized styles are ignored; a span with
        # no recognized styles is transparent (children processed into the
        # parent).
        class SpanHandler < BaseHandler
          STYLE_DECLARATION = /([a-z-]+)\s*:\s*([^;]+)/i
          BOLD_THRESHOLD = 600

          def process(element:, parent:)
            ast_classes_for(element["style"]).reduce(parent) do |current, klass|
              child = klass.new
              current << child
              child
            end
          end

          private

          def ast_classes_for(style)
            return [] if style.nil?

            classes = []
            style.scan(STYLE_DECLARATION) do |property, value|
              classes_for_declaration(property.downcase, value.downcase.rstrip).each do |klass|
                classes << klass unless classes.include?(klass)
              end
            end
            classes
          end

          def classes_for_declaration(property, value)
            case property
            when "text-decoration"
              text_decoration_classes(value)
            when "font-weight"
              bold_value?(value) ? [AST::Bold] : []
            when "font-style"
              italic_value?(value) ? [AST::Italic] : []
            else
              []
            end
          end

          def text_decoration_classes(value)
            classes = []
            classes << AST::Underline if value.include?("underline")
            classes << AST::Strikethrough if value.include?("line-through")
            classes
          end

          def bold_value?(value)
            return true if %w[bold bolder].include?(value)
            return false unless value.match?(/\A\d+\z/)

            Integer(value) >= BOLD_THRESHOLD
          end

          def italic_value?(value)
            %w[italic oblique].include?(value)
          end
        end
      end
    end
  end
end
