unless ENV['NO_COVERAGE']
  SimpleCov.minimum_coverage 100
  SimpleCov.start do
    add_filter '/spec/'

    track_files('app/**/*.rb')
    track_files('lib/**/*.rb')
    track_files('engines/**/app/**/*.rb')
    track_files('engines/**/lib/**/*.rb')
    track_files('engines/**/*.rb')
  end
end