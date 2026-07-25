# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for raw/preformatted tags that preserve content as-is
        class RawHandler < BaseHandler
          # A language must be one clean token — the renderer splices it
          # into the code fence line, so a class attribute with spaces or
          # other markup characters must not end up there.
          LANGUAGE_PATTERN = /\A[a-z0-9][a-z0-9_+-]*\z/
          private_constant :LANGUAGE_PATTERN

          def initialize(element_class)
            @element_class = element_class
          end

          def process(element:, parent:)
            # Get the inner text content
            content = element.inner_text

            ast_element =
              @element_class.new(language: language_for(element), block: block_for(element))
            ast_element << AST::Text.new(content) unless content.empty?
            parent << ast_element

            # Return nil to signal: don't process children (we handled content directly)
            nil
          end

          attr_reader :element_class

          private

          # <pre> is a block by definition, so its content keeps the fenced
          # form even on one line; <code> and <tt> leave the decision to the
          # renderer's newline check.
          #
          # @param element [Nokogiri::XML::Element]
          # @return [Boolean, nil]
          def block_for(element)
            true if element.name == "pre"
          end

          # The language of a code block, from the strongest signal to the
          # weakest: a `language-*` class on the element itself or on its
          # direct <code> child (the CommonMark convention for fenced code,
          # `<pre><code class="language-ruby">`), then the `lang` attribute,
          # then a lone class used as-is. A lone class ranks below `lang`
          # because a class can be pure styling (`hljs`, `prettyprint`).
          def language_for(element)
            code_child_classes = element.at_xpath("./code")&.[]("class")

            prefixed_language(element["class"]) || prefixed_language(code_child_classes) ||
              attribute_language(element["lang"]) || single_class_language(element["class"]) ||
              single_class_language(code_child_classes)
          end

          def prefixed_language(classes)
            classes
              &.split
              &.filter_map do |name|
                name.delete_prefix("language-").downcase if name.start_with?("language-")
              end
              &.find { |language| LANGUAGE_PATTERN.match?(language) }
          end

          def attribute_language(value)
            language = value&.strip&.downcase
            language if language&.match?(LANGUAGE_PATTERN)
          end

          def single_class_language(classes)
            names = classes&.split
            return unless names&.length == 1

            attribute_language(names.first)
          end
        end
      end
    end
  end
end
