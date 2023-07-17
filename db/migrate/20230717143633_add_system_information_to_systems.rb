class AddSystemInformationToSystems < ActiveRecord::Migration[6.1]
  def change
    # MySQL / MariaDB use the `json` data type as alias for longtext
    # in case you are wondering why schema.rb shows longtext.
    # See here: https://mariadb.com/kb/en/json-data-type/
    #
    # But it will automatically generate checking if the data in the column
    # is actually valid JSON
    # Something along the line:
    # add_check_constraint :systems, 'json_valid(`system_information`)', name: 'system_information'
    #
    # check schema.rb to see the result
    add_column :systems, :system_information, :json, default: {}
    add_column :systems, :instance_data, :string
  end
end
