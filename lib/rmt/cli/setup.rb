require 'yaml'
class RMT::CLI::Setup < RMT::CLI::Base
  DESTINATION_PATH = '/etc/rmt.conf'.freeze
  SOURCE_PATH = 'config/rmt.yml'.freeze
  POSITIVE_FEEDBACK = %w[Y y].freeze

  no_commands do
    def copy_conf_if_not_exists
      if File.exist?(DESTINATION_PATH)
        puts "File already exists at #{DESTINATION_PATH}."
      else
        puts "Copying file from #{SOURCE_PATH} to #{DESTINATION_PATH} as #{DESTINATION_PATH} does not exists"
        FileUtils.cp(SOURCE_PATH, DESTINATION_PATH)
        puts "File copied to #{DESTINATION_PATH}."
      end
    end

    def update_file(config_hash)
      file_contents = File.read(DESTINATION_PATH)
      file_data = YAML.load(file_contents)
      file_data['scc']['username'] = config_hash[:scc_username]
      file_data['scc']['password'] = config_hash[:scc_password]
      file_data['database']['database'] = config_hash[:db_dbname]
      file_data['database']['host'] = config_hash[:db_host]
      file_data['database']['username'] = config_hash[:db_username]
      file_data['database']['password'] = config_hash[:db_password]
      File.write(DESTINATION_PATH, file_data.to_yaml)
    end
  end

  def start_setup
    puts 'We are setting up system'
    copy_conf_if_not_exists
    loop do
      input = ask("Press enter/return to continue, else type 'exit' for exiting the cli")

      case input
      when 'exit'
        break
      else
        config_hash = {}
        config_hash[:scc_username] = ask('Enter SCC username, default is', default: 'root')
        config_hash[:scc_password] = ask('Enter SCC password, default is ', default: 'example', echo: false)
        puts "\n"
        config_hash[:db_host] = ask('Enter database host, default is ', default: 'localhost')
        config_hash[:db_username] = ask('Enter database username, default is ', default: 'rmt')
        config_hash[:db_password] = ask('Enter database password, default is ', default: 'rmt', echo: false)
        puts "\n"
        config_hash[:db_dbname] = ask('Enter database dbname, default is ', default: 'rmt_development')

        verify_data = ask("You have entered following data:\n
            scc_username: #{config_hash[:scc_username]}\n
            scc_password: ****\n
            db_host: #{config_hash[:db_host]}\n
            db_username: #{config_hash[:db_username]}\n
            db_password: ****\n
            db_dbname: #{config_hash[:db_dbname]}\n
            Enter Y(y) to continue else press enter/return to restart entering values: ")
        if POSITIVE_FEEDBACK.include?(verify_data)
          update_file(config_hash)
          puts 'Config updated, server restart is required using <systemctl restart rmt-server>'
          restart_rmt = ask('Do you wish to restart rmt server? (Enter Y(y) for yes else press enter to skip restart')
          if POSITIVE_FEEDBACK.include?(restart_rmt)
            puts 'Restarting Server....'
            `systemctl restart rmt-server`
          end
          break
        end
      end
    end
  end
end
