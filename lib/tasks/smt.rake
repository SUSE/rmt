namespace :smt do
  desc 'Sync products from SCC'
  task :sync, [:username, :password] => :environment do |_, args|
    Product.delete_all
    Repository.delete_all

    api = SUSE::Connect::Api.new(args[:username], args[:password])
    data = api.list_products

    data.each do |item|
      product = Product.new
      product.attributes = item.reject {|k, _| !product.attributes.keys.member?(k.to_s) }
      product.save!

      repositories = []
      item[:repositories].each do |repo_item|
        begin
          repository = Repository.new
          repository.attributes = repo_item.reject {|k, _| !repository.attributes.keys.member?(k.to_s) }
          repository.external_url = repo_item[:url]
          repository.save!
        rescue ActiveRecord::RecordNotUnique
          repository = Repository.where(name: repo_item[:name], distro_target: repo_item[:distro_target]).first
        end

        repositories << repository
      end

      service = Service.find_or_create_by( product_id: product.id )
      service.repositories = repositories
      service.save!
    end
  end
end
