require 'terminal-table'

module RMT::CLI::ArrayPrintable

  def array_to_table(array, options)
    rows = []

    array.all.each do |element|
      rows << options.keys.map { |k| element[k] }
    end
    Terminal::Table.new headings: options.values, rows: rows
  end

  def array_to_csv_table(array)
    CSV.generate { |csv| array.each { |row| csv << row } }
  end
end
