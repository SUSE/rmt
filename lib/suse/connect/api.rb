require 'rmt'
require 'rmt/http_request'
require 'rmt/logger'
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

      def connect_api
        # rubocop:disable Rails/Exit
        uri_string = Settings.try(:scc).try(:host) || 'https://scc.suse.com/connect'
        unless URI::DEFAULT_PARSER.make_regexp(['http', 'https']).match?(uri_string)
          @logger.error("Encountered an error validating #{uri_string}. Be sure to add http/https if it's an absolute url, i.e IP Address")
          exit
        end
        # rubocop:enable Rails/Exit

        uri_string.freeze
      end

      UUID_FILE_LOCATION = '/var/lib/rmt/system_uuid'.freeze

      # Amount of systems per update request
      BULK_SYSTEM_REQUEST_LIMIT = 50

      def initialize(username, password)
        @username = username
        @password = password
        @logger = RMT::Logger.new(STDOUT)
      end

      def list_orders
        make_paginated_request(:get, "#{connect_api}/organizations/orders")
      end

      def list_products
        make_paginated_request(:get, "#{connect_api}/organizations/products")
      end

      def list_products_unscoped
        make_paginated_request(:get, "#{connect_api}/organizations/products/unscoped")
      end

      def list_repositories
        make_paginated_request(:get, "#{connect_api}/organizations/repositories")
      end

      def list_subscriptions
        make_paginated_request(:get, "#{connect_api}/organizations/subscriptions")
      end

      def send_bulk_system_update(systems, system_limit = nil)
        system_limit ||= BULK_SYSTEM_REQUEST_LIMIT
        systems.in_batches(of: system_limit) do |batched_systems|
          params = prepare_payload_for_bulk_update(batched_systems)
          response = make_single_request(
            :put,
            "#{connect_api}/organizations/systems",
            { body: params.to_json }
          )
          yield response
        end
      rescue RequestError => e
        # change some params here and start the bulk update.
        if e.response.code == 413
          system_limit = e.response.headers['X-Payload-Entities-Max-Limit'].to_i
          return send_bulk_system_update(systems, system_limit)
        end
        raise e
      end

      def forward_system_deregistration(scc_system_id)
        make_request(:delete, "#{connect_api}/organizations/systems/#{scc_system_id}")
      rescue RequestError => e
        # don't raise an exception if the system was already deleted from SCC
        raise e unless e.response.code == 404
      end

      protected

      def prepare_payload_for_bulk_update(systems)
        mandatory_keys = %i[login password last_seen_at]

        systems_hash = systems.collect do |system|
          system_hash = system.attributes.symbolize_keys.slice(*mandatory_keys)

          # If a system has updated attributes other than `last_seen_at`,
          # scc_synced_at is reset to nil, to require a full sync.
          next system_hash unless system.scc_synced_at.nil?

          system_hash[:hostname] = system.hostname
          system_hash[:hwinfo] = generate_hwinfo_for(system)
          system_hash[:products] = generate_product_listing_for(system)
          system_hash
        end

        { systems: systems_hash }
      end

      def generate_product_listing_for(system)
        product_keys = %i[id identifier version arch]

        system.activations.map do |activation|
          attributes = activation.product.slice(*product_keys).symbolize_keys

          if activation.subscription
            attributes[:regcode] = activation.subscription.regcode
          end
          attributes
        end
      end

      def generate_hwinfo_for(system)
        hw_info_keys = %i[cpus sockets hypervisor arch uuid cloud_provider]

        return nil unless system.hw_info

        system.hw_info.attributes.symbolize_keys.slice(*hw_info_keys)
      end

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
          'HOST-SYSTEM' => host_system.to_s.strip,
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

      def host_system
        Settings.try(:host_system) || ''
      end

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
