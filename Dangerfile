# Flag that tells if any actual changes to the app were done
has_app_changes = !git.modified_files.grep(/lib/).empty? || !git.modified_files.grep(/app/).empty?

if !git.modified_files.include?('package/rmt-server.changes') && has_app_changes
  warn("Unless this is a trivial change, please include a CHANGELOG entry.\nRun `osc vc` in the `package` directory to add one.")
end

# Run rubocop, failing if there's any violations
rubocop.lint(report_danger: true, inline_comment: true)

# Check that the versions in all files are the same
def check_all_versions_equal
  if makefile_version != spec_version || makefile_version != rmt_version || spec_version != rmt_version
    error_msg = "The version of RMT is not consistent. These files must specify the same version:\n"
    error_msg << "- `lib/rmt.rb` specifies `#{rmt_version}`\n"
    error_msg << "- `Makefile` specifies `#{makefile_version}`\n"
    error_msg << "- `package/rmt-server.spec` specifies `#{spec_version}`"
    fail(error_msg)
  end
end

def makefile_version
  return @_makefile_version if defined?(@_makefile_version)
  @_makefile_version = File.open('Makefile', 'r') do |f|
    f.each_line do |line|
      break line.split('=').last.strip if line =~ /^VERSION/
    end
  end
end

def spec_version
  return @_spec_version if defined?(@_spec_version)
  @_spec_version = File.open('package/rmt-server.spec', 'r') do |f|
    f.each_line do |line|
      break line.split(':').last.strip if line =~ /^Version/
    end
  end
end

def rmt_version
  return @_rmt_version if defined?(@_rmt_version)
  require_relative 'lib/rmt.rb'
  @_rmt_version = RMT::VERSION
end

check_all_versions_equal
