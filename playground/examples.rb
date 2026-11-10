# frozen_string_literal: true

require "yaml"

module Markbridge
  module Playground
    # The examples of the playground. `examples/catalog.yml` names them per
    # format, the input of each one is a file next to it, so an example is
    # edited as the markup it is and not as a Ruby string.
    #
    # The first example of every format is "everything": every tag the
    # parser knows, with every alias. `examples_spec.rb` checks that
    # against the registries, so a new handler fails the spec until the
    # example shows it.
    module Examples
      DIRECTORY = File.join(__dir__, "examples")
      CATALOG = File.join(DIRECTORY, "catalog.yml")

      module_function

      # @return [Array<Hash>] id, format, slug, title, description and
      #   input of every example, in the order of the catalog
      def catalog
        YAML
          .safe_load_file(CATALOG)
          .flat_map do |format, entries|
            entries.map do |entry|
              file = entry.fetch("file")
              slug = File.basename(file, ".*")

              {
                id: "#{format}/#{slug}",
                format:,
                slug:,
                title: entry.fetch("title"),
                description: entry.fetch("description"),
                input: File.read(File.join(DIRECTORY, format, file), encoding: "UTF-8").chomp,
              }
            end
          end
      end

      # @param format [String]
      # @return [Hash] the example with every tag of the format
      def everything(format)
        catalog.find { |example| example[:format] == format && example[:slug] == "everything" }
      end
    end
  end
end
