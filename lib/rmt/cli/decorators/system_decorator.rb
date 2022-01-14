class RMT::CLI::Decorators::SystemDecorator < RMT::CLI::Decorators::Base

  attr_reader :data

  def initialize(systems, all: false)
    @data = if all
              [
                [
                  systems.login,
                  systems.hostname,
                  systems.registered_at,
                  systems.last_seen_at,
                  products_and_subscriptions(systems).join("\n")
                ]
              ]
            else
              systems.map do |system|
                [
                  system.login,
                  system.hostname,
                  system.registered_at,
                  system.last_seen_at,
                  products_and_subscriptions(system).join("\n")
                ]
              end
            end
    @headers = [ _('Login'), _('Hostname'), _('Registration time'), _('Last seen'), _('Products') ]
  end

  def products_and_subscriptions(system)
    system.activations.map do |a|
      product_name = a.service.product.product_string

      a.subscription ? "#{product_name} (Regcode: #{a.subscription.regcode})" : product_name
    end
  end

  def csv_headers
    headers_to_csv(@headers)
  end

  def to_csv(batch: false)
    array_to_csv(@data, @headers, batch: batch)
  end

  def to_table(large_rows: nil)
    return array_to_table(@data, @headers) if large_rows.nil?

    array_to_table(large_rows, @headers)
  end

end
