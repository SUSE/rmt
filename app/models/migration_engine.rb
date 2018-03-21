class MigrationEngine

  class MigrationEngineError < RuntimeError

    attr_accessor :data

    def initialize(message, data = nil)
      super(message)
      @data = data
    end

  end

  def initialize(system, provided_installed_products)
    @system = system
    @installed_products = provided_installed_products
  end

  def online_migrations
    generate(migration_kind: :online)
  end

  def offline_migrations(target_base_product)
    migrations = generate(migration_kind: :offline)
    filter_by_base_product(migrations, target_base_product)
  end

  def generate(migration_kind: :online)
    # check for migration attempt using products that have not been activated
    not_activated_products = @installed_products - @system.products

    if not_activated_products.present?
      raise MigrationEngineError.new(
        N_("The requested products '%s' are not activated on the system."),
        not_activated_products.map(&:friendly_name).join(', ')
      )
    end

    migrations = migration_targets(migration_kind: migration_kind)
    remove_incompatible_migrations(migrations)
    add_dependencies(migrations)
    # NB: It's possible to migrate to any product that's available on RMT, entitlement checks not needed.

    # Offering the most recent products first
    sort_migrations(migrations)
  end

  private

  def base_product
    return @base_product if @base_product
    bases = @installed_products.select(&:base?)
    raise MigrationEngineError.new(N_("Multiple base products found: '%s'."), bases.map(&:friendly_name).join(', ')) if bases.size > 1
    raise MigrationEngineError.new(N_('No base product found.')) if bases.empty?
    @base_product = bases.first
  end

  # returns the possible migration targets for @installed_products by grouping successor products
  def migration_targets(migration_kind: :online)
    migration_path_scope = (migration_kind == :online) ? ProductPredecessorAssociation.online : ProductPredecessorAssociation.offline
    installed_extensions = @installed_products.reject { |product| product == base_product }
    base_successors = base_product.successors.merge(migration_path_scope).to_a
    base_successors.push(base_product) if migration_kind == :online
    extension_successors = installed_extensions.map do |e|
      successors = e.successors.merge(migration_path_scope)
      successors += [e] if migration_kind == :online
      successors
    end
    # full set of migrations
    migrations = base_successors.product(*extension_successors)
    migrations.delete([base_product] + installed_extensions)
    migrations
  end

  # removes product combinations that include incompatible base-extension combinations
  def remove_incompatible_migrations(migrations)
    migrations.clone.each do |migration|
      migration_root_product = migration.first
      (migration - [migration_root_product]).each do |extension|
        # remove migration if it does not include a valid root product for the current extension
        if (extension.available_for.map(&:id) & migration.map(&:id)).empty?
          migrations.delete(migration)
          break
        end
      end
    end
  end

  # SLE 15 needs to have all of its available modules enabled, because there is
  # no direct mapping from SLE12 modules to SLE15 modules.
  # This method modifies the given array.
  def add_dependencies(migrations)
    migrations.map do |migration|
      base = migration.first
      if base.version.split('.').first == '15'
        migration.concat Product.available_or_recommended_modules(base.id)
      end
      migration
    end
  end

  def sort_migrations(migrations)
    migrations
      .map(&:uniq)
      .map { |migration| sort_migration(migration) }
      .sort_by { |migration| migration.map(&:version) }
      .reverse!
  end

  # we sort the migration products, so clients will activate them in the right dependency order
  def sort_migration(migration)
    base_product = migration.first # First product is the base
    sorted = []
    queue = [base_product]

    # Breadth-first search. We visit the products in the tree level by level,
    # and add them to the `sorted` array as we visit them.
    until queue.empty?
      product = queue.shift
      sorted << product
      # Exclude extensions that are not part of the migration
      # order(:name) prevents flickering tests
      extensions = product.extensions.for_root_product(base_product).order(:name).select { |e| migration.map(&:id).include?(e.id) }
      extensions.each { |ext| queue.push ext }
    end

    sorted
  end

  def filter_by_base_product(migrations, target_base_product)
    migrations.select { |migration| migration.first == target_base_product }
  end
end
