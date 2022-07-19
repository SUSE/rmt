class RMT::CLI::Decorators::SystemDecorator < RMT::CLI::Decorators::Base

  HEADERS = [ _('Login'), _('Hostname'), _('Registration time'), _('Last seen'), _('Products') ].freeze

  class << self
    def csv_headers
      CSV.generate { |csv| csv << HEADERS }
    end
  end

  def initialize(systems)
    @data = systems
  end

  def to_csv(batch: false)
    systems = systems_to_arrays
    array_to_csv(systems, HEADERS, batch: batch)
  end

  def to_table
    systems = systems_to_arrays(join_new_line: true)
    array_to_table(systems, HEADERS)
  end

  private

  attr_reader :data

  def systems_to_arrays(join_new_line: false)
    data.map do |system|
      [
        system.login,
        system.hostname,
        system.registered_at,
        system.last_seen_at,
        products_and_subscriptions(system, join_new_line: join_new_line)
      ]
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
