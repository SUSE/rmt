#! /usr/bin/env ruby
def modified_files
  `git fetch origin master`
  `git diff --name-only origin/master`.strip.split "\n"
end

def spec_version
  return @_spec_version if defined?(@_spec_version)

  @_spec_version = File.open('package/obs/rmt-server.spec', 'r') do |f|
    f.each_line do |line|
      break line.split(':').last.strip if /^Version/.match?(line)
    end
  end
end

def rmt_version
  return @_rmt_version if defined?(@_rmt_version)

  require_relative '../lib/rmt.rb'
  @_rmt_version = RMT::VERSION
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
  if !modified_files.include?('package/obs/rmt-server.changes')
    warning("Unless this is a trivial change, please include a CHANGELOG entry.\nRun 'osc vc' in the 'package' directory to add one.")
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
