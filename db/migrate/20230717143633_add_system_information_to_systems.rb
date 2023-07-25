class AddSystemInformationToSystems < ActiveRecord::Migration[6.1]
  def up
    # MySQL / MariaDB use the `json` data type as alias for longtext
    # in case you are wondering why schema.rb shows longtext.
    # See here: https://mariadb.com/kb/en/json-data-type/
    #
    # But it will automatically generate checking if the data in the column
    # is actually valid JSON
    # Something along the line:
    # add_check_constraint :systems, 'json_valid(`system_information`)', name: 'system_information'
    # check schema.rb to see the result
    #
    # NOTE: JSON/TEXT columns do not allow to set a default value!
    add_column :systems, :system_information, :json
    add_column :systems, :instance_data, :string
  end

  def down
    remove_column :systems, :system_information
    remove_column :systems, :instance_data
  end
end
