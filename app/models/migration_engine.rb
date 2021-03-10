class MigrationEngine

  class MigrationEngineError < RuntimeError

    attr_accessor :data

    def initialize(message, data = nil)
      super(message)
      @data = data
    end

  end

  # Python2 module was extracted from legacy module
  # so that it should be added by default during online migration between SLE 15
  PYTHON2_MODULE_IDENTIFIER = 'sle-module-python2'.freeze

  def initialize(system, provided_installed_products)
    @system = system
    @installed_products = provided_installed_products
  end

  def online_migrations
    generate(migration_kind: :online)
  end

  def offline_migrations(target_base_product)
    generate(migration_kind: :offline) do |migrations|
      migrations = filter_by_base_product(migrations, target_base_product)
      # Do not add extra migration modules when we are migrating to next service pack
      # i.e. if the migration path to target_base_product is 'online'
      unless ProductPredecessorAssociation.find_by(
        product_id: target_base_product.id,
        predecessor_id: base_product.id,
        kind: :online
      )
        add_migration_extras(migrations)
      end
      migrations
    end
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
    migrations = add_python2_module(migrations)
    migrations = yield(migrations) if block_given?
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
    migration_path_scope = (migration_kind == :online) ? ProductPredecessorAssociation.online : ProductPredecessorAssociation.all
    installed_extensions = @installed_products.reject { |product| product == base_product }
    base_successors = base_product.successors.merge(migration_path_scope).to_a
    base_successors.push(base_product) if migration_kind == :online
    combinations = []
    # adding all valid combinations of extension successors to the base successors
    base_successors.each do |base|
      extensions_successors = installed_extensions.map do |ext|
        options = ext.successors.merge(migration_path_scope)
        options += [ext] if migration_kind == :online
        options.select { |succ| succ.available_for?(base) }
      end
      combinations += [base].product(*extensions_successors)
    end
    combinations.delete([base_product] + installed_extensions)
    combinations
  end

  # automatically add modules that are flagged as `migration_extra` or `recommended`
  def add_migration_extras(migrations)
    migrations.map do |migration|
      base = migration.first
      migration.concat Product.modules_for_migration(base.id)
      migration
    end
  end

  def add_python2_module(migrations)
    migrations.map do |migration|
      base = migration.first
      # we need to add python2 module by default
      if base.version.split('.').first == '15'
        python2_module = Product.find_by(
          identifier: PYTHON2_MODULE_IDENTIFIER,
          arch: base.arch,
          version: base.version
        )
        migration.concat([python2_module]) if python2_module.present?
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
      .uniq
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
