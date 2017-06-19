namespace :smt do
  desc "Sync products from SCC"
  task :sync, [:username, :password] => :environment do |t, args|
    api = SUSE::Connect::Api.new( args[:username], args[:password] )
    data = api.get_products

    pp data
  end

end
