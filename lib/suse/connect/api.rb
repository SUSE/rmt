require 'rmt'
require 'rmt/http_request'
require 'json'

module SUSE
  module Connect
    class Api

      class InvalidCredentialsError < StandardError; end

      def initialize(username, password)
        @username = username
        @password = password
      end

      def list_orders
        make_paginated_request(:get, 'https://scc.suse.com/connect/organizations/orders')
      end

      def list_products
        make_paginated_request(:get, 'https://scc.suse.com/connect/organizations/products')
      end

      def list_products_unscoped
        make_paginated_request(:get, 'https://scc.suse.com/connect/organizations/products/unscoped')
      end

      def list_repositories
        make_paginated_request(:get, 'https://scc.suse.com/connect/organizations/repositories')
      end

      def list_subscriptions
        make_paginated_request(:get, 'https://scc.suse.com/connect/organizations/subscriptions')
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
        options[:accept_encoding] = 'gzip, deflate'
        options[:headers] = { 'RMT' => @username }

        response = RMT::HttpRequest.new(url, options).run
        raise InvalidCredentialsError if (response.code == 401)
        raise response.body unless (response.code >= 200 && response.code < 300)

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

        @entities
      end

    end
  end
end
