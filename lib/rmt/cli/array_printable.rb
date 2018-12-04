require 'csv'
require 'terminal-table'

module RMT::CLI::ArrayPrintable

  def array_to_csv(array)
    CSV.generate { |csv| array.each { |row| csv << row } }
  end

  def array_to_table(data, headers)
    Terminal::Table.new headings: headers, rows: data
  end

end
