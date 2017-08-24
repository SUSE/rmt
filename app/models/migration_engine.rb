class MigrationEngine

  class ProductsNotActivated < StandardError

    attr_accessor :products

    def initialize(message, products)
      super(message)
      @products = products
    end

  end

  def initialize(system, provided_installed_products)
    @system = system
    @installed_products = provided_installed_products
  end

  def generate
    # check for migration attempt using products that have not been activated
    not_activated_products = @installed_products - @system.products
    raise ProductsNotActivated.new('Products were not activated', not_activated_products) if not_activated_products.present?

    combinations = remove_incompatible_combinations(migration_targets)
    # NB: It's possible to migrate to any product that's available on RMT, entitlement checks not needed.

    # Offering the most recent products first
    combinations.sort_by { |c| c.map(&:version) }.reverse
  end

  private

  def base_product
    return @base_product if @base_product
    bases = @installed_products.select(&:base?)
    raise "Multiple base products found: #{bases.map(&:friendly_name)}" if bases.size > 1
    raise 'No base product found' if bases.empty?
    @base_product = bases.first
  end

  # returns the possible migration targets for @installed_products by grouping successor products
  def migration_targets
    installed_extensions = @installed_products - [base_product]
    base_successors = [base_product] + base_product.successors
    extension_successors = installed_extensions.map { |e| [e] + e.successors }
    # full set of combinations
    combinations = base_successors.product(*extension_successors)
    combinations.delete([base_product] + installed_extensions)
    combinations
  end

  # removes product combinations that include incompatible base-extension combinations
  def remove_incompatible_combinations(migrations)
    migrations.clone.each do |combination|
      combination_base_product = combination.first
      (combination - [combination_base_product]).each do |product|
        # remove combination if it includes no valid base product for the current product
        if (product.bases & combination).empty?
          migrations.delete(combination)
          break
        end
      end
    end
    migrations
  end

end
