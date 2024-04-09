require 'yaml'

AUTHORIZED_ACTION = ['pull'].freeze
# this is analogous to auth.Access in golang code.'
class AccessScope
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
    if @namespace.nil?
      @image == 'catalog' ? @actions : AUTHORIZED_ACTION
    else
      allowed_paths(client.systems.first)
      if @allowed_paths.any? { |allowed_path| File.fnmatch(@namespace + '*', allowed_path) }
        @actions & AUTHORIZED_ACTION
      else
        []
      end
    end
  end

  def self.raise_on_invalid_scope(scope)
    # if nothing is passed, return
    raise Registry::Exceptions::InvalidScope.new('Empty scope') if scope.blank?
    # if scope is malformed, return
    raise Registry::Exceptions::InvalidScope.new('Invalid scope format') unless scope.split(':').size == 3
    raise Registry::Exceptions::InvalidScope.new('Invalid scope format') unless %r{^[a-z0-9\-_/:*(),.]+$}i.match?(scope)
  end

  def allowed_paths(system = nil)
    repo_list = RegistryCatalogService.new.repos(reload: false, system: system)
    access_policies_yml = YAML.safe_load(
      File.read(Rails.application.config.access_policies)
    )
    active_products = system.activations.includes(:product).pluck(:product_class)

    allowed_products = (active_products & access_policies_yml.keys) + ['free']
    allowed_glob_paths = access_policies_yml.values_at(*allowed_products).flatten

    @allowed_paths = parse_repos(repo_list, allowed_glob_paths)
  end

  def parse_repos(repos, allowed_paths)
    filtered_repos = []

    allowed_paths.each do |allowed_path|
      pattern = allowed_path.gsub(/(?<!\*)\*(?!\*)/, '[^/]*').gsub('**', '.*')
      repos.each do |repo|
        next if filtered_repos.include? repo

        filtered_repos << repo unless (repo =~ /^#{pattern}$/).nil?
      end
    end
    filtered_repos
  end
end
