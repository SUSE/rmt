require 'yaml'

# The RMT::CLI::Setup class provides a command-line interface for setting up
# the RMT configuration/credentials. This class inherits from RMT::CLI::Base, which provides
# common functionality for all RMT command-line interfaces.
class RMT::CLI::Setup < RMT::CLI::Base
  # Constants for configuration file paths
  CONFIG_FILE_PATH = '/etc/rmt.conf'.freeze
  DEFAULT_CONFIG_PATH = 'config/rmt.yml'.freeze

  def initialize
    super
    # Load the default configuration file and merge it with the existing configuration (if any)
    @config = YAML.load_file(DEFAULT_CONFIG_PATH)
    @config.merge!(YAML.load_file(CONFIG_FILE_PATH)) if File.exist?(CONFIG_FILE_PATH)
  end

  # Start the RMT setup process
  desc "run_setup", "Run the application"
  def run_setup
    puts 'Starting RMT setup...'
    copy_default_config_file unless File.exist?(CONFIG_FILE_PATH)
    prompt_database_credentials
    prompt_scc_credentials
    confirm_and_write_config_file
    restart_rmt_process
  end

  private

  # Copy the default configuration file to the user's home directory
  def copy_default_config_file
    puts "File #{CONFIG_FILE_PATH} does not exists, creating a copy..."
    begin
      FileUtils.cp(DEFAULT_CONFIG_PATH, CONFIG_FILE_PATH)
    rescue Errno::EACCES => e
      puts "Unable to copy file: #{e.message}"
      puts "Please enter sudo password to copy the file to #{CONFIG_FILE_PATH}:"
      `sudo cp #{DEFAULT_CONFIG_PATH} #{CONFIG_FILE_PATH}`
    end
    puts "Copied #{DEFAULT_CONFIG_PATH} to #{CONFIG_FILE_PATH}"
  end

  # Prompt the user with a default value for input
  def prompt_with_default(prompt, default_value, hide_input: false)
    prompt = "#{prompt} (#{default_value}): " if default_value
    prompt = "#{prompt} (hidden input): " if hide_input
    input = ask(prompt, echo: !hide_input).chomp
    input.empty? ? default_value : input
  end

  # Prompt the user for the database credentials
  def prompt_database_credentials
    puts 'Please enter the following database credentials:'
    @config['database'] ||= {}
    @config['database']['host'] = prompt_with_default('Database Host', @config['database']['host'])
    @config['database']['database'] = prompt_with_default('Database', @config['database']['database'])
    @config['database']['username'] = prompt_with_default('Database Username', @config['database']['username'])
    @config['database']['password'] = prompt_with_default('Database Password', @config['database']['password'])
    puts 'Database credentials updated'
  end

  # Prompt the user for the SCC credentials
  def prompt_scc_credentials
    puts 'Please enter the SCC credentials:'
    @config['scc'] ||= {}
    @config['scc']['username'] = prompt_with_default('SCC Username', @config['scc']['username'])
    @config['scc']['password'] = prompt_with_default('SCC Password', @config['scc']['password'], hide_input: true)
    puts 'SCC credentials updated'
  end

  # Prompt the user to confirm the configuration changes and write them to the config file
  def confirm_and_write_config_file
    puts 'The following configuration values will be saved:'
    puts "database: host=#{@config['database']['host']}, username=#{@config['database']['username']}, password=#{@config['database']['password']}, database=#{@config['database']['database']}"
    puts "scc: username=#{@config['scc']['username']}, password=#{@config['scc']['password']}"

    loop do
      puts '=' * 70
      puts 'Do you want to save these changes? (y/n/x): '
      puts 'y: save the changes'
      puts 'n: repeat the database & SCC credentials'
      puts 'x: exit the program'
      input = ask('Choose any option').chomp.downcase

      case input
      when 'y'
        File.write(CONFIG_FILE_PATH, @config.to_yaml)
        puts "Changes saved to #{CONFIG_FILE_PATH}"
        break
      when 'n'
        prompt_database_credentials
        prompt_scc_credentials
      when 'x'
        abort('Changes discarded & Exiting...')
      else
        puts 'Invalid input. Please choose y, n, or x.'
      end
    end
  end

  # This method prompts the user to restart the RMT process to apply the new configuration.
  def restart_rmt_process
    input = ask('Do you want to restart the RMT process to apply the new configuration? (y/n): ').chomp.downcase
    if input == 'y'
      if Gem.win_platform?
        puts 'Windows platform detected, please manually restart the RMT server.'
      else
        # Use the `system` method to execute a shell command to restart the RMT server
        puts 'Restarting RMT server...'
        `sudo systemctl restart rmt-server`
        puts 'RMT server restarted.'
      end
    else
      puts 'RMT process will not be restarted, Exiting...'
    end
  end
end
