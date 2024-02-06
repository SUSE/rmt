#! /usr/bin/env ruby

def modified_files
  `git fetch origin master`
  `git diff --name-only origin/master`.strip.split "\n"
end

def spec_version
  return @spec_version if defined?(@spec_version)

  @spec_version ||= File.read('package/obs/rmt-server.spec')
    .match(/^Version:\s+(.+)\s*$/)
    .captures
    .first
end

def rmt_version
  @rmt_version ||= (require_relative 'lib/rmt' and RMT::VERSION)

  require_relative '../lib/rmt'
  @rmt_version = RMT::VERSION
end

def failure(msg)
  warning(msg)
  exit 1
end

def success
  puts 'Checks passed.'
end

def warning(msg)
  puts msg.to_s
end

def check
  # check changes
  unless modified_files.include?('package/obs/rmt-server.changes')
    warning("Warning: Unless this is a trivial change, please include a CHANGELOG entry.\nRun 'osc vc' in the 'package' directory to add one.")
  end

  if spec_version != rmt_version
    error_msg = "The version of RMT is not consistent. These files must specify the same version:\n"
    error_msg << "- `lib/rmt.rb` specifies `#{rmt_version}`\n"
    error_msg << "- `package/obs/rmt-server.spec` specifies `#{spec_version}`\n"
    failure(error_msg)
  end
  success
  exit 0
end

check
