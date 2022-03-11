class RMT::CLI::Decorators::SystemDecorator < RMT::CLI::Decorators::Base

  HEADERS = [ _('Login'), _('Hostname'), _('Registration time'), _('Last seen'), _('Products') ].freeze

  class << self
    def csv_headers
      CSV.generate { |csv| csv << HEADERS }
    end
  end

  attr_reader :data

  def initialize(systems)
    @data = systems.map do |system|
      [
        system.login,
        system.hostname,
        system.registered_at,
        system.last_seen_at,
        products_and_subscriptions(system).join("\n")
      ]
    end
  end

  def products_and_subscriptions(system)
    system.activations.map do |a|
      product_name = a.service.product.product_string

      a.subscription ? "#{product_name} (Regcode: #{a.subscription.regcode})" : product_name
    end
  end

  def to_csv(batch: false)
    array_to_csv(@data, HEADERS, batch: batch)
  end

  def to_table
    array_to_table(@data, HEADERS)
  end

end
