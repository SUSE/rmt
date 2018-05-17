require 'csv'
require 'ostruct'


class SMTImporter
  attr_accessor :data_dir
  attr_accessor :no_systems

  class ImportException < StandardError
  end

  def initialize(data_dir, no_systems)
    @data_dir = data_dir
    @no_systems = no_systems
  end

  def read_csv(file)
    # set the quote char to something not used to make sure the csv parser is not interfering with the
    # JSON quoting.
    CSV.open(File.join(data_dir, file + '.csv'), 'r', { col_sep: "\t", quote_char: "\x00" })
  end

  def import_repositories
    read_csv('enabled_repos').each do |row|
      repo_id, = row
      repo = Repository.find_by(scc_id: repo_id)
      if repo
        repo.mirroring_enabled = true
        repo.save!
        puts "Enabled mirroring for repository #{repo_id}"
      else
        warn "Repository #{repo_id} was not found in RMT database, perhaps you no longer have a valid subscription for it"
      end
    end
  end

  def import_custom_repositories
    read_csv('enabled_custom_repos').each do |row|
      product_id, repo_name, repo_url = row

      product = Product.find_by(id: product_id)
      repo = Repository.find_or_create_by(external_url: repo_url) do |repository|
        repository.name = repo_name
        repository.local_path = Repository.make_local_path(repo_url)
      end

      if product
        assoc = repo.services.find_by(id: product.service)
        unless assoc
          repo.services << product.service
          puts "Added association between #{repo.name} and product #{product_id}"
        end
      else
        warn "Product #{product_id} not found!"
        warn "Tried to attach custom repository #{repo.name} to product #{product_id},"
        warn 'but that product was not found. Attach it to a different product'
        warn 'by running `rmt-cli repos custom attach`'
      end
    end
  end

  def import_systems
    read_csv('systems').each do |row|
      login, password, hostname, registered_at = row

      next unless System.find_by(login: login, password: password).nil?

      # rubocop:disable Rails/TimeZone
      System.create!(
        login: login,
        password: password,
        hostname: hostname,
        registered_at: Time.at(registered_at.to_i)
      )
      # rubocop:enable Rails/TimeZone
      puts "Imported system #{login}"
    end
  end

  def import_activations
    read_csv('activations').each do |row|
      login, product_id = row

      product = Product.find_by(id: product_id)
      system = System.find_by(login: login)

      if !system
        warn "System #{login} not found"
        next
      elsif !product
        warn "Product #{product_id} not found"
        next
      else
        activation = Activation.find_by(system: system, service: product.service)
        unless activation
          Activation.create!(system: system, service: product.service)
          puts "Imported activation of #{product_id} for #{login}"
        end
      end
    end
  end

  def import_hardware_info
    systems = {}

    # create hardware infos
    read_csv('hw_info').each do |row|
      login, key, value = row
      next unless key == 'machinedata'

      systems[login] = JSON.parse(value)['hwinfo']
    end

    systems.each do |login, info|
      system = System.find_by(login: login)

      unless system
        warn "System #{login} not found"
        next
      end
      info.delete('hostname')

      HwInfo.find_or_initialize_by(system: system).update!(info)
      puts "Hardware information stored for system #{login}"
    end
  end

  def run(argv)
    parse_cli_arguments argv
    check_products_exist

    ActiveRecord::Base.transaction do
      import_repositories
      import_custom_repositories
    end

    return if no_systems

    ActiveRecord::Base.transaction do
      import_systems
      import_activations
      import_hardware_info
    end
  end

  def parse_cli_arguments(argv)
    parser = OptionParser.new do |parser|
      parser.on('-d', '--data PATH', 'Path to unpacked SMT data tarball') { |path| @data_dir = path }
      parser.on('--no-systems', 'Do not import the systems that were registered to the SMT') { @no_systems = true }
    end
    parser.parse!(argv)
    raise OptionParser::MissingArgument if data_dir.nil?
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
    puts parser
    raise ImportException
  end

  def check_products_exist
    return if Product.count > 0
    warn 'RMT has not been synced to SCC yet. Please run `rmt-cli sync` before'
    warn 'importing data from SMT.'
    raise ImportException
  end
end
