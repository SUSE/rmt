module SUSE
  module Connect
    class Api
      def initialize( username, password )
        @username = username
        @password = password
      end

      def get_products
        return make_request( :get,'https://scc.suse.com/connect/organizations/products' )
      end

      protected

      def make_request( method, url, options = {} )
        options[:userpwd] = "#{@username}:#{@password}" unless options[:userpwd]
        options[:method] = method
        options[:accept_encoding] = %w{gzip deflate}

        options[:headers] ||= {}
        options[:headers][:user_agent] = 'SMT-NG' # TODO add version

        response = Typhoeus::Request.new( url, options ).run
        raise response.body unless ( response.code >= 200 and response.code < 300 )

        return JSON.parse( response.body )
      end

    end
  end
end
