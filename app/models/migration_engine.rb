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
    generate
  end

  def offline_migrations(target_base_product)
    migrations = generate
    filter_by_base_product(migrations, target_base_product)
  end

  private

  def generate
    # check for migration attempt using products that have not been activated
    not_activated_products = @installed_products - @system.products

    if not_activated_products.present?
      raise MigrationEngineError.new(
        N_("The requested products '%s' are not activated on the system."),
        not_activated_products.map(&:friendly_name).join(', ')
      )
    end

    migrations = remove_incompatible_combinations(migration_targets)
    # NB: It's possible to migrate to any product that's available on RMT, entitlement checks not needed.

    # Offering the most recent products first
    sort_migrations(migrations)
  end

  def base_product
    return @base_product if @base_product
    bases = @installed_products.select(&:base?)
    raise MigrationEngineError.new(N_("Multiple base products found: '%s'."), bases.map(&:friendly_name).join(', ')) if bases.size > 1
    raise MigrationEngineError.new(N_('No base product found.')) if bases.empty?
    @base_product = bases.first
  end

  # returns the possible migration targets for @installed_products by grouping successor products
  def migration_targets
    installed_extensions = @installed_products.reject { |product| product == base_product }
    base_successors = [base_product] + base_product.successors
    extension_successors = installed_extensions.map { |e| [e] + e.successors }
    # full set of migrations
    migrations = base_successors.product(*extension_successors)
    migrations.delete([base_product] + installed_extensions)
    migrations
  end

  # removes product combinations that include incompatible base-extension combinations
  def remove_incompatible_combinations(migrations)
    migrations.reject do |migration|
      migration[1..-1].any? do |product|
        (product.bases & migration).empty?
      end
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
