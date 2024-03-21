require 'yaml'

AUTHORIZED_ACTION = ['pull'].freeze
# this is analogous to auth.Access in golang code.
class Registry::AccessScope
  attr_accessor :type,
                :class,
                :namespace,
                :image,
                :actions

  # Parses a String into an authorization scope.
  #
  # scope - a String containing an authorization scope in the following format:
  #         `<type>[(<class>)]:<namespace>/<image>:<actions>`
  #         `repository(special):name:pull`
  #         `registry:catalog:*`
  #
  # Returns a new Scope.
  def self.parse(scope)
    raise_on_invalid_scope(scope)
    type, name, actions = scope.split(':')
    _, type, klass = /(\w+)\(?(\w+)?\)?/.match(type).to_a
    actions = actions.split(',')
    new(type: type, klass: klass, name: name, actions: actions)
  end

  def initialize(type:, name:, actions:, klass: nil)
    @type = type
    @klass = klass
    @namespace, _, @image = name.rpartition('/').map(&:strip).map(&:presence)
    @actions = actions
  end

  def full_type
    return "#{@type}(#{@klass})" if @klass.present?

    @type
  end

  def to_s
    "#{full_type}:#{name}:#{@actions.join(',')}"
  end

  def granted(client: nil)
    aa = authorized_actions(client)
    Rails.logger.info "Granted actions for user '#{client&.account || '<anonymous>'}': #{aa}"
    {
      'type' => @type,
      'class' => @klass,
      'name' => name,
      'actions' => aa
    }
  end

  def name
    [namespace, image].map(&:presence).compact.join('/')
  end

  def authorized_actions(client = nil)
    allowed_paths(client)
    if @allowed_paths.any?{|allowed_path| @namespace.include?(allowed_path.chomp('/')) }
      # remove '/' as last character from allowed path as
      # @namespace comes from splitting name string by '/'
      @actions & AUTHORIZED_ACTION
    else
      []
    end
  end

  def self.raise_on_invalid_scope(scope)
    # if nothing is passed, return
    raise Registry::Exceptions::InvalidScope.new('Empty scope') if scope.blank?
    # if scope is malformed, return
    raise Registry::Exceptions::InvalidScope.new('Invalid scope format') unless scope.split(':').size == 3
    raise Registry::Exceptions::InvalidScope.new('Invalid scope format') unless %r{^[a-z0-9\-_/:*(),.]+$}i.match?(scope)
  end

  def self.allowed_paths(client = nil)
    access_policies_yml = YAML.load(
      File.read(Rails.application.config.access_policies)
    )
    active_products = client.systems.first.activations.includes(:product).pluck(:identifier)
    sles_index = active_products.index('SLES')
    active_products[sles_index] = '7261' unless sles_index.nil? # for [historic] reasons, SLES identifier in the yaml is the product class as string

    allowed_products = active_products & access_policies_yml.keys
    @allowed_paths = access_policies_yml.values_at(*allowed_products).flatten.map { |allowed_path| allowed_path[0..allowed_path.index('*') - 1] }
  end
end
