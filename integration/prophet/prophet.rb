#!/usr/bin/env ruby

require 'prophet'
require 'logger'
require 'yaml'
require_relative 'ci_executor'

Prophet.setup do |config|
  # Setup Github access.
  CONFIG_FILE = File.expand_path('options-local.yml', __dir__)

  if File.exist?(CONFIG_FILE)
    options = YAML.load_file(CONFIG_FILE)
    # The GitHub (GH) username/password to use for commenting on a successful run.
    config.username = options['default']['gh_username']
    config.password = options['default']['gh_password']

    # The GH credentials for commenting on failing runs (can be the same as above).
    # NOTE: If you specify two different accounts with different avatars, it's
    # a lot easier to spot failing test runs at first glance.
    config.username_fail = options['default']['gh_username_fail']
    config.password_fail = options['default']['gh_password_fail']
  end

  # Setup logging.
  config.logger = log = @logger = Logger.new(STDOUT)
  log.level = Logger::INFO

  # Now that GitHub has fixed their notifications system, we can dare to increase
  # Prophet's verbosity and use a new comment for every run.
  config.reuse_comments = false

  # Set failure / success messages and add Jenkins URL if available.
  jenkins_url = `echo $BUILD_URL`.chomp
  if jenkins_url.empty?
    message = ''
  else
    message = "\n#{jenkins_url}console\nIf the given link has expired,"
    message += 'you can force a Prophet rerun by just deleting this comment.'
  end
  config.comment_failure = 'Prophet reports failure.' + message
  config.comment_success = 'Well Done! Your tests are still passing.' + message

  # Specify which tests to run. (Defaults to `rake test`.)
  # NOTE: Either ensure the last call in that block runs your tests
  # or manually set @result to a boolean inside this block.
  config.execution do
    executor = SCC::CiExecutor.new(logger: config.logger)
    executor.run!

    config.success = executor.success?

    if config.success
      log.info 'All tests are passing.'
    else
      config.comment_failure += "\n#{executor.fail_message}"
      log.info 'Some tests are failing.'
      executor.inspect_failed

      throw RuntimeError, config.comment_failure
    end
  end
end

# Finally, run Prophet!
Prophet.run
