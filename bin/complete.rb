#!/usr/bin/env ruby

# Thor / ActiveSupport path magic
rmt_path = File.expand_path('..', __dir__)
require_relative '../config/boot'
$LOAD_PATH.unshift File.join(rmt_path, 'lib')

require 'active_support'

relative_load_paths = %w[lib lib/rmt/cli/].map { |dir| File.join(rmt_path, dir) }
ActiveSupport::Dependencies.autoload_paths += relative_load_paths
# magic ends here

# MAIN:
completion = RMT::CLI::Completion.new
if !completion.correct_capitalization? then exit 0 end
completion.generate_static_options
completion.generate_completions

completion.complete
