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
    active_product_classes = system.activations.includes(:product).pluck(:product_class)
    allowed_product_classes = (active_product_classes & access_policies_yml.keys)
    if system && system.hybrid?
      # if the system is hybrid => check if the non free product subscription is still valid for accessing images
      allowed_non_free_product_classes = allowed_product_classes.map { |s| s unless Product.find_by(product_class: s).free? }
      unless allowed_non_free_product_classes.empty?
        auth_header = {
          Authorization: ActionController::HttpAuthentication::Basic.encode_credentials(system.login, system.password)
        }
        allowed_non_free_product_classes.each do |non_free_prod_class|
          activation_state = SccProxy.scc_check_subscription_expiration(
            auth_header, system.login, system.system_token, Rails.logger, system.proxy_byos_mode, non_free_prod_class
            )
          unless activation_state[:is_active]
            Rails.logger.info(
              "Access to #{non_free_prod_class} from system #{system.login} denied: #{activation_state[:message]}"
            )
            # remove the non active non free product extension from the allowed paths
            allowed_product_classes -= [non_free_prod_class]
          end
        end
      end
    end
    allowed_glob_paths = access_policies_yml.values_at(*allowed_product_classes).flatten
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
