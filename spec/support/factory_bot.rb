RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # load factories owned by the plugins
  if ENV['RMT_LOAD_ENGINES']
    Dir.glob('engines/*/spec/factories/').each do |dir|
      FactoryBot.definition_file_paths << Pathname.new(File.expand_path(dir))
    end

    FactoryBot.reload
  end
end
