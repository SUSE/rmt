module SUSE
  module Connect
    class Api

      def initialize(username, password)
        @username = username
        @password = password
      end

      def list_products
        make_paginated_request(:get, 'https://scc.suse.com/connect/organizations/products')
      end

      protected

      def process_rels(response)
        links = (response.headers['Link'] || '').split(', ').map do |link|
          href, name = link.match(/<(.*?)>; rel="(\w+)"/).captures
          [name.to_sym, href]
        end
        Hash[*links.flatten]
      end

      def make_request(method, url, options)
        options[:userpwd] = "#{@username}:#{@password}" unless options[:userpwd]
        options[:method] = method
        options[:accept_encoding] = %w(gzip deflate)

        options[:headers] ||= {}
        options[:headers][:user_agent] = 'SMT-NG' # TODO: add version

        response = Typhoeus::Request.new(url, options).run
        raise response.body unless (response.code >= 200 and response.code < 300)

        response
      end

      def make_single_request(method, url, options = {})
        response = make_request(method, url, options)
        JSON.parse(response.body, symbolize_names: true)
      end

      def make_paginated_request(method, url, options = {})
        @page = 1
        @entities = []
        loop do
          options[:params] ||= {}
          options[:params][:page] = @page

          response = make_request(method, url, options)
          links = process_rels(response)

          @entities += JSON.parse(response.body, symbolize_names: true)

          @page += 1
          break unless links[:next]
        end

        return @entities
      end

    end
  end
end
