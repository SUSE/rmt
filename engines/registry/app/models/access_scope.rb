# this is analogous to auth.Access in golang code.
Module Registry
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
      # aa = authorized_actions(client)
      # TODO: decide on a policy to grant a system access to products/images
      # in the meantime, allow access to any action
      # if basisc auth is OK (username/password)
      aa = @actions
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

    # there can be multiple policies matching the same scope, for example one for admins
    # and one for customers
    def policies
      unless @policies
        @policies = Registry::AccessPolicy.get_by_scope(self)

        if @policies.present?
          Rails.logger.info "Matched AccessPolicies for '#{self}': '#{@policies.map(&:to_s)}'"
        else
          Rails.logger.info "No AccessPolicy found for '#{self}'"
        end
      end
      @policies
    end

    def authorized_actions(client = nil)
      @actions.intersection(policies.map { |p| p.authorized_actions(client: client) }.flatten.uniq)
    end

    def self.raise_on_invalid_scope(scope)
      # if nothing is passed, return
      raise Registry::Exceptions::InvalidScope.new('Empty scope') if scope.blank?
      # if scope is malformed, return
      raise Registry::Exceptions::InvalidScope.new('Invalid scope format') unless scope.split(':').size == 3
      raise Registry::Exceptions::InvalidScope.new('Invalid scope format') unless %r{^[a-z0-9\-_/:*(),.]+$}i.match?(scope)
    end
  end
end
