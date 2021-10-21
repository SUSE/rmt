class RMT::CLI::Decorators::SystemDecorator < RMT::CLI::Decorators::Base

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
    @headers = [ _('Login'), _('Hostname'), _('Registration time'), _('Last seen'), _('Products') ]
  end

  def products_and_subscriptions(system)
    system.activations.map do |a|
      product_name = a.service.product.product_string

      a.subscription ? "#{product_name} (Regcode: #{a.subscription.regcode})" : product_name
    end
  end

  def to_csv
    array_to_csv(@data, @headers)
  end

  def to_table
    array_to_table(@data, @headers)
  end

end
