class Product < ApplicationRecord

  has_one :service, dependent: :destroy
  has_many :repositories, through: :service

  has_many :product_extensions_associations,
           class_name: 'ProductsExtensionsAssociation',
           foreign_key: :extension_id

  has_many :bases,
           through: :product_extensions_associations,
           source: :product

  # Product extensions - get list of product extensions
  has_many :extension_products_associations,
           class_name: 'ProductsExtensionsAssociation',
           foreign_key: :product_id

  has_many :root_products, -> { distinct },
           through: :product_extensions_associations

  has_many :extensions, -> { distinct },
    through: :extension_products_associations,
    source: :extension do
    def for_root_product(root_product)
      where('products_extensions.root_product_id = %s', root_product.id)
    end
  end

  has_many :mirrored_extensions, -> { mirrored },
    through: :extension_products_associations,
    source: :extension do
    def for_root_product(root_product)
      where('products_extensions.root_product_id = %s', root_product.id)
    end
  end

  has_and_belongs_to_many :predecessors, class_name: 'Product', join_table: :product_predecessors,
    association_foreign_key: :predecessor_id

  has_and_belongs_to_many :successors, class_name: 'Product', join_table: :product_predecessors,
    association_foreign_key: :product_id, foreign_key: :predecessor_id

  enum product_type: { base: 'base', module: 'module', extension: 'extension' }

  scope :free, -> { where(free: true) }
  scope :mirrored, lambda {
    distinct.joins(:repositories).where('repositories.enabled = true').group(:id).having('count(*)=count(CASE WHEN mirroring_enabled THEN 1 END)')
  }
  scope :migration_extra, lambda { |root_product_ids|
    joins(:product_extensions_associations)
    .where(products_extensions: { root_product_id: root_product_ids, migration_extra: true })
  }
  scope :recommended, lambda { |root_product_ids|
    joins(:product_extensions_associations)
    .where(products_extensions: { root_product_id: root_product_ids, recommended: true })
  }

  scope :with_release_stage, lambda { |release_stage|
    if release_stage
      where(release_stage: release_stage)
    else
      all
    end
  }

  def has_extension?
    ProductsExtensionsAssociation.exists?(product_id: id)
  end

  def mirror?
    enabled = repositories.select(&:enabled).to_a
    disabled = repositories.reject(&:enabled).to_a

    # If we have enabled repositories, return true if any are enabled to be mirrored.
    return enabled.reject(&:mirroring_enabled).empty? unless enabled.empty?

    # If we only have disabled repositories, return true if any are enabled to be mirrored.
    return disabled.reject(&:mirroring_enabled).empty? unless disabled.empty?

    false
  end

  def last_mirrored_at
    repositories.where(mirroring_enabled: true).maximum(:last_mirrored_at)
  end

  def self.clean_up_version(version)
    return unless version
    [version, version.tr('-', '.').chomp('.0')].uniq
  end

  def safe_friendly_version
    friendly_version || version
  end

  def product_string
    [identifier, version, arch].join('/')
  end

  def friendly_name
    [name, friendly_version, release_type, (arch if arch != 'unknown')].compact.join(' ')
  end

  def change_repositories_mirroring!(conditions, mirroring_enabled)
    repos = repositories.where(conditions)
    repo_names = repos.pluck(:name)
    repos.update_all(mirroring_enabled: mirroring_enabled)

    repo_names.sort
  end

  def recommended_for?(root_product)
    product_extensions_associations.where(recommended: true).where(root_product: root_product).present?
  end

  def available_for?(product)
    root_products.include?(product) || product == self
  end

  def self.modules_for_migration(root_product_ids)
    migration_extra(root_product_ids).or(recommended(root_product_ids)).distinct
  end

  def self.free_and_recommended_modules(root_product_ids)
    joins(:product_extensions_associations).free
        .where(products_extensions: { root_product_id: root_product_ids })
        .or(recommended_extensions(root_product_ids))
        .distinct
  end

  def self.recommended_extensions(root_product_ids)
    joins(:product_extensions_associations).where(products_extensions: { recommended: true, root_product_id: root_product_ids })
  end

  def create_service!
    service = Service.find_by(product_id: id)
    return service if service

    service ||= if Service.find_by(id: id)
                  # for backward-compatibility: create a service with autoincrement ID, if product.id is already occupied
                  Service.create!(product_id: id)
                else
                  # create a service with service.id = product.id for keeping consistent service URLs across RMT instances
                  Service.create!(id: id, product_id: id)
                end

    service
  end

  def self.get_by_target!(target)
    product_id = Integer(target, 10) rescue nil

    products = []
    if product_id
      product = find(product_id)
      products << product unless product.nil?
    else
      identifier, version, arch = target.split('/')
      conditions = { identifier: identifier, version: version }
      conditions[:arch] = arch if arch
      products = where(conditions).to_a
    end

    products
  end
end
