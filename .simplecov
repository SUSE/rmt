unless ENV['NO_COVERAGE']

  if !ENV['SIMPLECOV_CMD'] || ENV['SIMPLECOV_CMD'] == 'test:core'
    SimpleCov.minimum_coverage 100
    SimpleCov.start do
      SimpleCov.command_name ENV['SIMPLECOV_CMD']
      add_filter '/spec/'
      add_filter '/tasks/'

      # omit registration sharing (removing systems using rmt-cli)
      add_filter('engines/registration_sharing/lib/registration_sharing.rb')
      add_filter('lib/rmt.rb')
      add_filter('lib/rmt/config.rb')
      add_filter('lib/rmt/db.rb')


      track_files('app/**/*.rb')
      track_files('lib/**/*.rb')
    end
  end

  if ENV['SIMPLECOV_CMD'] == 'test:engines'
    SimpleCov.minimum_coverage 100
    SimpleCov.start do
      SimpleCov.command_name ENV['SIMPLECOV_CMD']
      add_filter '/spec/'
      add_filter '/tasks/'

      track_files('engines/**/*.rb')
    end
  end

end
