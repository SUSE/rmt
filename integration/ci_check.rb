#! /usr/bin/env ruby

def work_dir(path, &block)
  return nil unless block_given?

  old_dir = Dir.pwd
  Dir.chdir path
  yield block
  Dir.chdir old_dir
end

def modified_files
  files = ''
  work_dir '../' do
    puts "Fetching master... #{Dir.pwd}"
    `git fetch origin master`
    puts "Computing diff with master #{Dir.pwd}"
    files = `git diff --name-only master`.strip.split "\n"
  end
  files
end

def spec_version
  return @_spec_version if defined?(@_spec_version)

  @_spec_version = File.open('../package/obs/rmt-server.spec', 'r') do |f|
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

def fail(msg)
  `echo ::error ""`
  `echo ::set-output name=error::msg::msg ""`
  `echo ::set-output name=error::msg::msg "#{msg}"`
  exit 1
end

def success
  `echo ::success ""`
  `echo ::set-output name=success::msg::msg ""`
  `echo ::set-output name=success::msg::msg "Checks passed."`
  exit 0
end

def warning(msg)
  `echo ::warning ""`
  `echo ::set-output name=warning::msg::msg ""`
  `echo ::set-output name=warning::msg::msg "#{msg}"`
end

def check

  # check changes
  unless modified_files.include?('package/obs/rmt-server.changes')
    warning("Unless this is a trivial change, please include a CHANGELOG entry.\nRun 'osc vc' in the 'package' directory to add one.")
  end

  if spec_version != rmt_version
    error_msg = "The version of RMT is not consistent. These files must specify the same version:\n"
    error_msg << "- `lib/rmt.rb` specifies `#{rmt_version}`\n"
    error_msg << "- `package/obs/rmt-server.spec` specifies `#{spec_version}`\n"
    fail(error_msg)
  end
  success
end

check
