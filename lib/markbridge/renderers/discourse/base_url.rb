# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Makes the relative address of a link or an image absolute, the way
      # a browser does on a page at the base URL.
      #
      # Discourse drops an address that has no scheme and no leading
      # slash, and an address with a leading slash points to the Discourse
      # site, not to the site the post comes from. With a base URL both
      # keep pointing to where they pointed in the source.
      #
      # @example
      #   base = BaseUrl.new("https://wiki.example.com/wiki/Main_Page")
      #   base.resolve("./Alta_Via")   # => "https://wiki.example.com/wiki/Alta_Via"
      #   base.resolve("/files/a.png") # => "https://wiki.example.com/files/a.png"
      #   base.resolve("https://example.org/") # => "https://example.org/"
      class BaseUrl
        PARTS = %r{\A(https?://[^/?#\s]+)([^?#\s]*)}i
        SCHEME = /\A[a-z][a-z0-9+.-]*:/i
        private_constant :PARTS, :SCHEME

        # @param url [String] an http or https URL. Its last path segment
        #   is a page, like in a browser: relative addresses are next to
        #   it. End the URL with a slash to resolve inside a directory.
        # @raise [ArgumentError] when +url+ is no http or https URL
        def initialize(url)
          match = PARTS.match(url)
          unless match
            raise ArgumentError, "base_url must be an http or https URL, got #{url.inspect}"
          end

          @origin = match[1]
          @path = match[2].empty? ? "/" : match[2]
          @directory = @path[..@path.rindex("/")]
        end

        # @param address [String, nil] the href of a link or the src of an
        #   image
        # @return [String, nil] the absolute address. An address with a
        #   scheme, one that starts with `//` or `#`, an empty one and nil
        #   come back as they are.
        def resolve(address)
          return address if address.nil? || address.empty? || address.match?(SCHEME)

          case address[0]
          when "#"
            address
          when "/"
            address.start_with?("//") ? address : "#{@origin}#{address}"
          when "?"
            "#{@origin}#{@path}#{address}"
          else
            "#{@origin}#{without_dot_segments(@directory + address)}"
          end
        end

        private

        # `a/./b` is `a/b` and `a/x/../b` is `a/b`, in the path only: a
        # query or a fragment is left as it is.
        def without_dot_segments(location)
          path, rest = location.split(/(?=[?#])/, 2)
          segments =
            path
              .split("/")
              .each_with_object([]) do |segment, kept|
                case segment
                when "."
                  nil
                when ".."
                  kept.pop if kept.size > 1
                else
                  kept << segment
                end
              end
          # A slash or a dot segment at the end names a directory.
          slash = "/" if path.end_with?("/", "/.", "/..")

          "#{segments.join("/")}#{slash}#{rest}"
        end
      end
    end
  end
end
