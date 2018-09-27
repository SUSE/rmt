#!/usr/bin/env ruby

# Thor / ActiveSupport path magic
rmt_path = File.expand_path('..', __dir__)
require_relative '../config/boot'
$LOAD_PATH.unshift File.join(rmt_path, 'lib')

require 'active_support'

relative_load_paths = %w[lib lib/rmt/cli/].map { |dir| File.join(rmt_path, dir) }
ActiveSupport::Dependencies.autoload_paths += relative_load_paths
# magic ends here

# helper functions:
def get_options(command)
  submodule = command.slice(0,1).capitalize + command.slice(1, command.length).downcase
  begin
    options = RMT::CLI.module_eval(submodule).commands.keys
  rescue NameError
    options = []
  end
end

def split_feed
  words = ENV['COMP_LINE'].split(' ')
  index = words.length - 1
  if ENV['COMP_LINE'][-1] == ' '
    index += 1
  end
  return words, index
end

# main completion routine
def complete

  words, index = split_feed
  completions = []
  current_word = words[index] || ''
  previous_word = words[index-1] unless words[index-1] == 'rmt-cli'
  options = get_options(previous_word || 'main')

  options.each do |option|
    if option.start_with?(current_word)
      completions.append(option)
    end
  end

  completions
end

print complete.join("\n")
