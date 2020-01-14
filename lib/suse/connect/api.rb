require 'rmt'
require 'rmt/http_request'
require 'json'

module SUSE
  module Connect
    class Api

      class InvalidCredentialsError < StandardError; end
      class RequestError < StandardError
        attr_reader :response

        def initialize(response)
          @response = response
          super()
        end
      end

      CONNECT_API_URL = 'https://scc.suse.com/connect'.freeze
      UUID_FILE_LOCATION = '/var/lib/rmt/system_uuid'.freeze

      def initialize(username, password)
        @username = username
        @password = password
      end

      def list_orders
        make_paginated_request(:get, "#{CONNECT_API_URL}/organizations/orders")
      end

      def list_products
        make_paginated_request(:get, "#{CONNECT_API_URL}/organizations/products")
      end

      def list_products_unscoped
        make_paginated_request(:get, "#{CONNECT_API_URL}/organizations/products/unscoped")
      end

      def list_repositories
        make_paginated_request(:get, "#{CONNECT_API_URL}/organizations/repositories")
      end

      def list_subscriptions
        make_paginated_request(:get, "#{CONNECT_API_URL}/organizations/subscriptions")
      end

      def forward_system_activations(system)
        product_keys = %i[id identifier version arch]
        hw_info_keys = %i[cpus sockets hypervisor arch uuid cloud_provider]

        hw_info = system.hw_info ? system.hw_info.attributes.symbolize_keys.slice(*hw_info_keys) : nil

        params = {
          login: system.login,
          password: system.password,
          hostname: system.hostname,
          regcodes: [],
          products: system.products.select(*product_keys).map { |i| i.attributes.symbolize_keys },
          hwinfo: hw_info
        }

        make_single_request(
          :post,
          "#{CONNECT_API_URL}/organizations/systems",
          { body: params.to_json }
        )
      end

      def forward_system_deregistration(scc_system_id)
        make_request(:delete, "#{CONNECT_API_URL}/organizations/systems/#{scc_system_id}")
      rescue RequestError => e
        # don't raise an exception if the system was already deleted from SCC
        raise e unless e.response.code == 404
      end

      protected

      def process_rels(response)
        links = (response.headers['Link'] || '').split(', ').map do |link|
          href, name = link.match(/<(.*?)>; rel="(\w+)"/).captures
          [name.to_sym, href]
        end
        Hash[*links.flatten]
      end

      def make_request(method, url, options = {})
        options[:userpwd] = "#{@username}:#{@password}" unless options[:userpwd]
        options[:method] = method
        options[:accept_encoding] = 'gzip, deflate'
        options[:headers] = {
          'RMT' => system_uuid.strip,
          'Accept' => 'application/vnd.scc.suse.com.v4+json',
          'Content-Type' => 'application/json'
        }

        response = RMT::HttpRequest.new(url, options).run
        raise InvalidCredentialsError if (response.code == 401)
        raise RequestError.new(response) unless (response.code >= 200 && response.code < 300)

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

      private

      def system_uuid
        @system_uuid ||= if File.exist?(UUID_FILE_LOCATION) && !File.empty?(UUID_FILE_LOCATION)
                           File.read(UUID_FILE_LOCATION)
                         else
                           uuid = SecureRandom.uuid
                           File.write(UUID_FILE_LOCATION, uuid)
                           uuid
                         end
      end
    end
  end
end
