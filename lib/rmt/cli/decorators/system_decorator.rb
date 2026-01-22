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

  def to_table(add_headers: true, style: {}, width: [0, 0, 0, 0, 0])
    systems = systems_to_arrays(join_new_line: true, width: width)
    headers = add_headers ? HEADERS : []
    width.each_with_index { |col_width, index| headers[index].ljust(col_width) } if headers.present? && width[0] != 0

    array_to_table(systems, headers, style)
  end

  private

  attr_reader :data

  def systems_to_arrays(join_new_line: false, width: [0, 0, 0, 0, 0])
    data.map do |system|
      [
        system.login.ljust(width[0]),
        system.hostname.ljust(width[1]),
        system.registered_at.to_s.ljust(width[2]),
        system.last_seen_at.to_s.ljust(width[3]),
        products_and_subscriptions(system, join_new_line: join_new_line, width: width[4])
      ]
    end
  end

  def products_and_subscriptions(system, join_new_line: false, width: 0)
    products = system.activations.map do |a|
      product_name = a.service.product.product_string

      a.subscription ? "#{product_name.ljust(width)}\n" + "(Regcode: #{a.subscription.regcode})".ljust(width) : product_name.ljust(width)
    end
    return ''.ljust(width) if products.empty?

    join_new_line ? products.join("\n") : products.join(' ')
  end

end
