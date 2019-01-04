RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods

  # load factories owned by the plugins
  if (ENV['RMT_LOAD_ENGINES'])
    Dir.glob('engines/*/spec/factories/').each do |dir|
      FactoryGirl.definition_file_paths << Pathname.new(File.expand_path(dir))
    end

    FactoryGirl.reload
  end
end
