class RMT::CLI::Decorators::RegistrationDecorator < RMT::CLI::Decorators::Base

  def initialize(systems)
    @data = systems.map do |system|
      [
        system.login,
        system.hostname,
        system.registered_at,
        system.last_seen_at,
        system.products.map { |p| p.identifier.downcase + '/' + p.version + '/' + p.arch }.join("\n")
      ]
    end
    @headers = [ _('Login'), _('Hostname'), _('Registration time'), _('Last seen'), _('Products') ]
  end

  def to_csv
    array_to_csv(@data, @headers)
  end

  def to_table
    array_to_table(@data, @headers)
  end

end
