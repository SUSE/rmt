require 'active_record'

require_relative '../app/models/application_record.rb'

Dir[File.join(__dir__, '..', 'app', 'models', '**', '*.rb')].each { |file| require File.expand_path(file) }

db_config_path = File.join(__dir__, '../config/database.yml')
db_config = YAML.safe_load(ERB.new(File.read(db_config_path)).result, [], [], true)

ActiveRecord::Base.establish_connection(db_config['development'])
