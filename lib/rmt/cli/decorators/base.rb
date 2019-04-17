require 'csv'
require 'terminal-table'

class RMT::CLI::Decorators::Base

  def to_csv
    raise NotImplementedError
  end

  def to_table
    raise NotImplementedError
  end

  protected

  def array_to_csv(array, headers)
    CSV.generate { |csv| array.unshift(headers).each { |row| csv << row } }
  end

  def array_to_table(data, headers)
    Terminal::Table.new headings: headers, rows: data
  end

end
