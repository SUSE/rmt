require 'csv'
require 'terminal-table'

module RMT::CLI::ArrayPrintable

  def format_array(array, array_options, csv_format)
    rows = array.map do |element|
      array_options.keys.map { |k| element.public_send(k) }
    end
    if csv_format
      array_to_csv(rows)
    else
      array_to_table(rows, array_options)
    end
  end

  def array_to_csv(array)
    CSV.generate { |csv| array.each { |row| csv << row } }
  end

  def array_to_table(array, options)
    Terminal::Table.new headings: options.values, rows: array
  end

end
