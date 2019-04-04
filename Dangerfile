unless git.modified_files.include?('package/obs/rmt-server.changes')
  warn("Unless this is a trivial change, please include a CHANGELOG entry.\nRun `osc vc` in the `package` directory to add one.")
end

# Run rubocop, failing if there's any violations
rubocop.lint(report_danger: true, inline_comment: true, force_exclusion: true)

# Check that the versions in all files are the same
def check_all_versions_equal
  if spec_version != rmt_version
    error_msg = "The version of RMT is not consistent. These files must specify the same version:\n"
    error_msg << "- `lib/rmt.rb` specifies `#{rmt_version}`\n"
    error_msg << "- `package/obs/rmt-server.spec` specifies `#{spec_version}`\n"
    fail(error_msg)
  end
end

def spec_version
  return @_spec_version if defined?(@_spec_version)
  @_spec_version = File.open('package/obs/rmt-server.spec', 'r') do |f|
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
