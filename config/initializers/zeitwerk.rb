Rails.autoloaders.each do |autoloader|
  autoloader.inflector = Zeitwerk::Inflector.new
  autoloader.inflector.inflect(
    'rmt' => 'RMT',
    'cli' => 'CLI',
    'suse' => 'SUSE',
    'scc' => 'SCC',
    'gpg' => 'GPG',
    'smt_importer' => 'SMTImporter'
  )
end
