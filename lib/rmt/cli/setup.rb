require 'yaml'
class RMT::CLI::Setup < RMT::CLI::Base
  DEFAULT_CONFIG_PATH = 'config/rmt.yml'.freeze
  CONFIG_PATH = 'etc/rmt.conf'.freeze

  def initialize
    super
    @config = {}
  end

  desc 'setup_configuration', 'Setup RMT configuration file'
  def setup_configuration
    puts "\e[2J\e[f" # clean screen

    puts '---------------------------------------'
    puts '|  Setting up RMT configuration file  |'
    puts '---------------------------------------'

    load_configuration
    update_configuration
    confirm_save_configuration
    restart_process
  end

  private

  # Check whether file exist
  def file_exist?(file_path)
    File.exist?(file_path)
  end

  # Copying file
  def copy_file(source, destination)
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp(source, destination)
  rescue StandardError
    abort('Unable to copy the file')
  end

  # Load File and return its content
  def load_file_data(file_path)
    YAML.load_file(file_path)
  rescue StandardError
    abort('Unable to load the file')
  end

  # Write content to file
  def write_file(file_path, data, mode: 'w')
    File.open(file_path, mode) { |f| f.write(data) }
  rescue StandardError
    abort('Unable to update the config')
  end

  # Take input from user
  def user_input(message, default: nil)
    print "#{message} "
    print "(#{default}) " unless default.nil?

    input_value = $stdin.gets.chomp
    input_value.blank? ? default : input_value
  end

  # Loading configuration
  def load_configuration
    # Copy Default config if config file not exist
    unless file_exist?(CONFIG_PATH)
      puts "\nNo #{CONFIG_PATH} file found. Copying default config file from #{DEFAULT_CONFIG_PATH}"
      copy_file(DEFAULT_CONFIG_PATH, CONFIG_PATH)
    end

    # Loading config data
    @config.merge!(load_file_data(CONFIG_PATH))
  end

  # Set Configuration
  def update_configuration
    puts "\n"
    puts 'Enter development database configuration:'
    update_database_configuration
    puts "\n"
    puts 'Enter test database configuration:'
    update_database_configuration(env: 'test')
    puts "\n"
    puts 'Enter SCC Configuration:'
    puts 'Note: If unable to get username/password, Contact to `https://myaccount.suse.com/help/login#report-security`'
    update_scc_configuration

    @config.delete('database') # Removing unwanted key
  end

  # Show Configuration
  def show_configuration
    puts "\n"
    puts 'Development database configuration:'
    show_database_configuration
    puts "\n"
    puts 'Test database configuration:'
    show_database_configuration(env: 'test')
    puts "\n"
    puts 'SCC Configuration:'
    show_scc_configuration
  end

  # Set Database Configuration
  def update_database_configuration(env: 'development')
    database = @config["database_#{env}"] || @config['database'] || {}
    @config["database_#{env}"] = {} if @config["database_#{env}"].nil?

    @config["database_#{env}"]['host'] = user_input(' Database Host: ', default: database['host'])
    @config["database_#{env}"]['database'] = user_input(' Database Name: ', default: database['database'])
    @config["database_#{env}"]['username'] = user_input(' Database Username: ', default: database['username'])
    @config["database_#{env}"]['password'] = user_input(' Database Password: ', default: database['password'])
    @config["database_#{env}"]['adapter'] = user_input(' Database Adapter: ', default: database['adapter'])
  end

  # Show Database Configuration
  def show_database_configuration(env: 'development')
    database = @config["database_#{env}"] || {}
    puts " Database Host: #{database['host']}"
    puts " Database Name: #{database['database']}"
    puts " Database Username: #{database['username']}"
    puts " Database Password: #{database['password']}"
    puts " Database Adapter: #{database['adapter']}"
  end

  # Set SCC Configuration
  def update_scc_configuration
    scc = @config['scc'] || {}
    scc['host'] = user_input(' SCC Host: ', default: scc['host'])
    scc['username'] = user_input(' SCC Username: ', default: scc['username'])
    scc['password'] = user_input(' SCC Password: ', default: scc['password'])
    scc['sync_systems'] = user_input(' SCC System Sync: ', default: scc['sync_systems'])
  end

  # Show SCC Configuration
  def show_scc_configuration
    scc = @config['scc'] || {}
    puts " SCC Host: #{scc['host']}"
    puts " SCC Username: #{scc['username']}"
    puts " SCC Password: #{scc['password']}"
    puts " SCC System Sync: #{scc['sync_systems']}"
  end

  # Show configuration and menu
  def confirm_save_configuration
    puts "\n"
    puts "The following key-value pairs will be written to #{CONFIG_PATH}:"

    show_configuration

    loop do
      puts "\n"
      choice = user_input('Do you want to save? (y/n):')
      case choice
      when 'y'
        save_configuration
        break
      when 'n'
        abort('Changes are discarded and Exiting')
      else
        warn _('Enter valid option')
      end
    end
  end

  # Save New Configuration to file
  def save_configuration
    write_file(CONFIG_PATH, @config.to_yaml)
    puts "Configuration updated to #{CONFIG_PATH}"
  end

  # Restarting RMT Process
  def restart_process
    puts "\n"
    loop do
      restart_input = user_input('RMT process need to restart for new configuration. Do you want to continue. (y/n):')
      case restart_input
      when 'y'
        puts 'RMT process restarting...'
        system('systemctl restart rmt-server')
        abort('RMT process restarted')
      when 'n'
        abort('Please restart the RMT process manually')
      else
        warn _('Enter valid option')
      end
    end
  end
end
