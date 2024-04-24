namespace :registry do
  desc 'Refresh Repository Cache'
  task refresh_cache: :environment do
    repo_count = RegistryCatalogService.new.repos(reload: true).size
    puts "Refresh done. Got #{repo_count} repos."
  end
end
