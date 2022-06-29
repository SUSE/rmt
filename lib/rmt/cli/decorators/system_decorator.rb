class RMT::CLI::Decorators::SystemDecorator < RMT::CLI::Decorators::Base

  HEADERS = [ _('Login'), _('Hostname'), _('Proxy BYOS'), _('Registration time'), _('Last seen'), _('Products') ].freeze

  class << self
    def csv_headers
      CSV.generate { |csv| csv << HEADERS }
    end
  end

  def initialize(systems)
    @data = systems
  end

  def to_csv(batch: false, proxy_byos: false)
    systems = systems_to_arrays(proxy_byos: proxy_byos)
    array_to_csv(systems, HEADERS, batch: batch)
  end

  def to_table(proxy_byos: false)
    systems = systems_to_arrays(join_new_line: true, proxy_byos: proxy_byos)
    array_to_table(systems, HEADERS)
  end

  private

  attr_reader :data

  def systems_to_arrays(join_new_line: false, proxy_byos: false)
    if proxy_byos
      proxy_byos_systems = data.map do |system|
        if system.proxy_byos
          [
            system.login,
            system.hostname,
            system.proxy_byos,
            system.registered_at,
            system.last_seen_at,
            products_and_subscriptions(system, join_new_line: join_new_line)
          ]
        end
      end
      proxy_byos_systems = proxy_byos_systems.compact
      return [] if proxy_byos_systems.empty?

      proxy_byos_systems
    else
      data.map do |system|
        [
          system.login,
          system.hostname,
          system.proxy_byos,
          system.registered_at,
          system.last_seen_at,
          products_and_subscriptions(system, join_new_line: join_new_line)
        ]
      end
    end
  end

  def products_and_subscriptions(system, join_new_line: false)
    products = system.activations.map do |a|
      product_name = a.service.product.product_string

      a.subscription ? "#{product_name} (Regcode: #{a.subscription.regcode})" : product_name
    end

    join_new_line ? products.join("\n") : products.join(' ')
  end

end
