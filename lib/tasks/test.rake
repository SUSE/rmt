require 'simplecov'
require 'rspec/core/rake_task'

task 'test' => ['test:core', 'test:engines']

RSpec::Core::RakeTask.new('test:core') do |t|
  SimpleCov.command_name 'core'
  t.pattern = 'spec'
  t.verbose = false
  t.fail_on_error = false
  t.rspec_opts = '--format Fuubar --color'
end

RSpec::Core::RakeTask.new('test:engines') do |t|
  ENV['RMT_LOAD_ENGINES'] = '1'
  SimpleCov.command_name 'engines'
  t.pattern = 'engines/strict_authentication/'
  t.verbose = false
  t.fail_on_error = false
  t.rspec_opts = '--format Fuubar --color'
end

