# Flag that tells if any actual changes to the app were done
has_app_changes = !git.modified_files.grep(/lib/).empty? || !git.modified_files.grep(/app/).empty?

if !git.modified_files.include?('package/rmt-server.changes') && has_app_changes
  warn("Unless this is a trivial change, please include a CHANGELOG entry.\nRun `osc vc` to add one.")
end

# Run rubocop, failing if there's any violations
rubocop.lint(report_danger: true)
