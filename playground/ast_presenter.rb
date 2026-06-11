# frozen_string_literal: true

module Markbridge
  module Playground
    class ASTPresenter
      CATEGORY_MAP = {
        "Align" => "formatting",
        "Attachment" => "media",
        "Bold" => "formatting",
        "Code" => "code",
        "Color" => "formatting",
        "Details" => "block",
        "Document" => "document",
        "Email" => "link",
        "Event" => "block",
        "Heading" => "block",
        "HorizontalRule" => "structure",
        "Image" => "media",
        "Italic" => "formatting",
        "LineBreak" => "structure",
        "List" => "block",
        "ListItem" => "block",
        "MarkdownText" => "text",
        "Mention" => "link",
        "Paragraph" => "block",
        "Poll" => "block",
        "Quote" => "block",
        "Size" => "formatting",
        "Spoiler" => "formatting",
        "Strikethrough" => "formatting",
        "Subscript" => "formatting",
        "Superscript" => "formatting",
        "Table" => "block",
        "TableCell" => "block",
        "TableRow" => "block",
        "Text" => "text",
        "Underline" => "formatting",
        "Upload" => "media",
        "Url" => "link",
      }.freeze

      ICON_MAP = {
        "Align" => "alignCenter",
        "Attachment" => "paperclip",
        "Bold" => "bold",
        "Code" => "terminal",
        "Color" => "palette",
        "Details" => "chevronsDownUp",
        "Document" => "treePine",
        "Email" => "mail",
        "Event" => "calendarDays",
        "Heading" => "heading",
        "HorizontalRule" => "minus",
        "Image" => "image",
        "Italic" => "italic",
        "LineBreak" => "cornerDownLeft",
        "List" => "list",
        "ListItem" => "chevronRight",
        "MarkdownText" => "wholeWord",
        "Mention" => "atSign",
        "Paragraph" => "pilcrow",
        "Poll" => "barChart",
        "Quote" => "messageSquareQuote",
        "Size" => "aLargeSmall",
        "Spoiler" => "eyeOff",
        "Strikethrough" => "strikethrough",
        "Subscript" => "subscript",
        "Superscript" => "superscript",
        "Table" => "table",
        "TableCell" => "squareAsterisk",
        "TableRow" => "rows3",
        "Text" => "textCursor",
        "Underline" => "underline",
        "Upload" => "upload",
        "Url" => "link",
      }.freeze

      def initialize(node)
        @node = node
      end

      def render
        [label_for(@node)].concat(
          children_for(@node).flat_map.with_index do |child, index|
            lines_for(child, prefix: "", is_last: index == children_for(@node).length - 1)
          end,
        ).join("\n")
      end

      def as_json
        serialize(@node, depth: 0)
      end

      def stats
        aggregate_stats(@node, depth: 0)
      end

      private

      def lines_for(node, prefix: "", is_last: true)
        connector = is_last ? "└─ " : "├─ "
        line = "#{prefix}#{connector}#{label_for(node)}"
        children = children_for(node)
        next_prefix = "#{prefix}#{is_last ? "   " : "│  "}"

        [line].concat(
          children.flat_map.with_index do |child, index|
            lines_for(child, prefix: next_prefix, is_last: index == children.length - 1)
          end,
        )
      end

      def label_for(node)
        attributes = attribute_pairs(node).map { |name, value| "#{name}=#{value.inspect}" }
        [node.class.name.split("::").last, *attributes].join(" ")
      end

      def serialize(node, depth:)
        {
          type: type_name(node),
          kind: node_kind(node),
          category: category_for(node),
          icon: icon_for(node),
          label: label_for(node),
          preview: preview_for(node),
          attributes: attribute_pairs(node).to_h,
          depth:,
          children_count: children_for(node).length,
          children: children_for(node).map { |child| serialize(child, depth: depth + 1) },
        }
      end

      def aggregate_stats(node, depth:)
        children = children_for(node)

        child_stats = children.map { |child| aggregate_stats(child, depth: depth + 1) }

        {
          node_count: 1 + child_stats.sum { |entry| entry[:node_count] },
          element_count:
            (node.is_a?(Markbridge::AST::Element) ? 1 : 0) +
              child_stats.sum { |entry| entry[:element_count] },
          text_node_count:
            (node.is_a?(Markbridge::AST::Text) ? 1 : 0) +
              child_stats.sum { |entry| entry[:text_node_count] },
          leaf_node_count:
            (children.empty? ? 1 : 0) + child_stats.sum { |entry| entry[:leaf_node_count] },
          max_depth: [depth, *child_stats.map { |entry| entry[:max_depth] }].max,
        }
      end

      def type_name(node)
        node.class.name.split("::").last
      end

      def node_kind(node)
        if node.is_a?(Markbridge::AST::Element)
          "element"
        elsif node.is_a?(Markbridge::AST::Text)
          "text"
        else
          "leaf"
        end
      end

      def category_for(node)
        CATEGORY_MAP.fetch(type_name(node), "generic")
      end

      def icon_for(node)
        ICON_MAP.fetch(type_name(node), "generic")
      end

      def attribute_pairs(node)
        node
          .instance_variables
          .filter_map do |ivar|
            name = ivar.to_s.delete_prefix("@")
            next if name == "children"

            value = node.instance_variable_get(ivar)
            next if value.nil?

            [name, value]
          end
          .sort_by(&:first)
      end

      def preview_for(node)
        return truncate(node.text) if node.is_a?(Markbridge::AST::Text)
        return nil if node.is_a?(Markbridge::AST::Element)

        formatted = attribute_pairs(node).map { |name, value| "#{name}=#{value.inspect}" }.join(" ")
        formatted.empty? ? nil : truncate(formatted, length: 72)
      end

      def children_for(node)
        if node.is_a?(Markbridge::AST::Element)
          node.children
        elsif node.is_a?(Markbridge::AST::Text)
          []
        else
          []
        end
      end

      def truncate(text, length: 48)
        return text if text.length <= length

        "#{text[0, length - 1]}…"
      end
    end
  end
end
