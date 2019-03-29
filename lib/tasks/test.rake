require 'rspec/core/rake_task'

task :test do
  require 'simplecov'
  Rake::Task['test:core'].execute
  Rake::Task['test:engines'].execute
end

RSpec::Core::RakeTask.new('test:core') do |t|
  ENV['SIMPLECOV_CMD'] = 'test:core'
  t.pattern = 'spec'
  t.verbose = false
  t.fail_on_error = true
  t.rspec_opts = '--format Fuubar --color'
end

RSpec::Core::RakeTask.new('test:engines') do |t|
  ENV['RMT_LOAD_ENGINES'] = '1'
  ENV['SIMPLECOV_CMD'] = 'test:engines'
  t.pattern = 'engines/*/spec/**/**{,/*/**}/*_spec.rb'
  t.verbose = false
  t.fail_on_error = true
  t.rspec_opts = '--format Fuubar --color'
end
