class RMT::CLI::Setup < RMT::CLI::Base
  CONFIG_FILE = '/etc/rmt.conf'.freeze
  DEVELOPMENT_CONFIG_FILE = './config/rmt.yml'.freeze
  DB_CONFIG = 'database'.freeze
  SCC_CONFIG = 'scc'.freeze

  desc 'setup', _('Update user configurations required for RMT setup')
  def setup
    puts _('-------- Starting RMT server setup ---------')
    copy_to_config_file unless File.exist?(CONFIG_FILE)
    update_config
    confirm_details_and_save
  end

  private

  # Copies the development config file to the main config file for RMT
  def copy_to_config_file
    puts "\n" + (_('Could not find config at %{config_file}') % { config_file: CONFIG_FILE })
    puts _('Copying config from %{development_config_file} to %{config_file}') % { development_config_file: DEVELOPMENT_CONFIG_FILE,
                                                                                   config_file: CONFIG_FILE }
    begin
      FileUtils.cp(DEVELOPMENT_CONFIG_FILE, CONFIG_FILE)
      puts _('Config copied successfully!')
    rescue StandardError => e
      puts _('Failed to copy configuration. Error : %{error_message}') % { error_message: e.message }
      abort _('Aborting.')
    end
  end

  # Prompts user to specify new configs or uses previously set config
  def update_config
    @config = YAML.load_file(CONFIG_FILE)

    @new_config = {}
    puts "\n" + _('Please enter the following database configurations: ')
    @new_config[DB_CONFIG] = {}
    @new_config[DB_CONFIG]['database'] = input_prompt_generator('database', @config[DB_CONFIG]['database'])
    @new_config[DB_CONFIG]['username'] = input_prompt_generator('username', @config[DB_CONFIG]['username'])
    @new_config[DB_CONFIG]['password'] = input_prompt_generator('password', @config[DB_CONFIG]['password'], sensitive_data: true)

    puts "\n\n" + _('Please enter your SCC credentials: ')
    puts _('NOTE: You can find them in https://scc.suse.com under the Proxies tab.')
    @new_config[SCC_CONFIG] ||= {}
    @new_config[SCC_CONFIG]['username'] = input_prompt_generator('username', @config[SCC_CONFIG]['username'])
    @new_config[SCC_CONFIG]['password'] = input_prompt_generator('password', @config[SCC_CONFIG]['password'], sensitive_data: true)
  end

  def confirm_details_and_save
    loop do
      input = ask("\n\n" + _('Would you like to save the updated configuration? (y/n/exit) : ')).downcase

      case input
      when 'y'
        # Merging updated configs with the older config for updation and saving result to CONFIG_FILE
        @config = @config.deep_merge(@new_config)
        begin
          File.write(CONFIG_FILE, @config.to_yaml)
        rescue StandardError
          puts _('Failed to save config. Please retry.')
        end
        puts _('Successfully updated the configuration!')
        restart_rmt
        break
      when 'n'
        update_config
      when 'exit'
        confirmation = ask(_('You are attempting to exit before saving the configuration. Are you sure? (y/n) : ')).downcase
        if confirmation == 'y'
          puts _('Aborted')
          break
        elsif confirmation == 'n'
          next
        else
          puts _('Invalid input. Please try again.')
        end
      else
        puts _('Invalid input. Please try again.')

      end
    end

  end

  # Constructs the prompt message to be displayed to users to fetch config field data
  # Displays the existing default value to the user, if present
  # Example => username (Press enter for John ) :
  def input_prompt_generator(config_field, default_value, sensitive_data: false)
    prompt = config_field.to_s

    # Show default_value as "*****" for sensitive fields
    unless default_value.empty?
      prompt << ' ('
      prompt << _('Press enter for ')
      prompt << "#{sensitive_data ? '*****' : default_value} "
      prompt << ')'
    end
    prompt << ' : '

    input = ask(prompt, echo: !sensitive_data)
    input.empty? ? default_value : input
  end

  # Restarts the RMT process
  def restart_rmt
    loop do
      puts "\n" + _('RMT must be restarted with the updated configuration.')
      input = ask(_('Restart RMT automatically? (y/n) : ')).downcase
      case input
      when 'y'
        begin
          puts _('Restarting RMT server. Please wait.')
          `systemctl restart rmt-server`
          puts _('Successfully restarted RMT server.')
        rescue StandardError => e
          puts _('Failed to restart RMT server. Error : %{error_message}') % { error_message: e.message }
        end
        break
      when 'n'
        puts _('Please restart the RMT server manually.')
        break
      else
        puts _('Invalid input. Please try again.')
      end
    end
  end

end
