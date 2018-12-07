unless ENV['NO_COVERAGE']
  SimpleCov.minimum_coverage 100
  SimpleCov.start do
    SimpleCov.command_name ENV['SIMPLECOV_CMD']
    add_filter '/spec/'
    add_filter '/tasks/'

    track_files('app/**/*.rb')
    track_files('lib/**/*.rb')
    track_files('engines/**/app/**/*.rb')
    track_files('engines/**/lib/**/*.rb')
    track_files('engines/**/*.rb')
  end
end