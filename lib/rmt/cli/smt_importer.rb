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
      repo_id, _ = row
      repo = Repository.find_by(scc_id: repo_id)
      if repo
        repo.mirroring_enabled = true
        repo.save!
        puts _('Enabled mirroring for repository %{repo}') % { repo: repo_id }
      else
        warn _('Repository %{repo} was not found in RMT database, perhaps you no longer have a valid subscription for it') % { repo: repo_id }
      end
    end
  end

  def import_custom_repositories
    read_csv('enabled_custom_repos').each do |row|
      product_id, repo_name, repo_url = row

      repo_url += '/' unless repo_url.ends_with?('/')

      product = Product.find_by(id: product_id)
      repo = Repository.find_or_create_by(external_url: repo_url) do |repository|
        repository.name = repo_name
        repository.local_path = Repository.make_local_path(repo_url)
      end

      if product
        assoc = repo.services.find_by(id: product.service)
        unless assoc
          repo.services << product.service
          puts _('Added association between %{repo} and product %{product}') % { repo: repo.name, product: product.id }
        end
      else
        warn _(<<-WARNING
Product %{product} not found!
Tried to attach custom repository %{repo} to product %{product},
but that product was not found. Attach it to a different product
by running `%{command}`
WARNING
) % { repo: repo.name, product: product_id, command: 'rmt-cli repos custom attach' }
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
      puts _('Imported system %{system}') % { system: login }
    end
  end

  def import_activations
    read_csv('activations').each do |row|
      login, product_id = row

      product = Product.find_by(id: product_id)
      system = System.find_by(login: login)

      if !system
        warn _('System %{system} not found') % { system: login }
        next
      elsif !product
        warn _('Product %{product} not found') % { product: product_id }
        next
      else
        activation = Activation.find_by(system: system, service: product.service)
        unless activation
          Activation.create!(system: system, service: product.service)
          puts _('Imported activation of %{product} for %{system}') % { product: product_id, system: login }
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
        warn _('System %{system} not found') % { system: login }
        next
      end
      info.delete('hostname')

      HwInfo.find_or_initialize_by(system: system).update!(info)
      puts _('Hardware information stored for system %{system}') % { system: login }
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
      parser.on('-d', '--data PATH', _('Path to unpacked SMT data tarball')) { |path| @data_dir = path }
      parser.on('--no-systems', _('Do not import the systems that were registered to the SMT')) { @no_systems = true }
    end
    parser.parse!(argv)
    raise OptionParser::MissingArgument if data_dir.nil?
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
    puts parser
    raise ImportException
  end

  def check_products_exist
    return if Product.count > 0
    warn _('RMT has not been synced to SCC yet. Please run `%{command}` before') % { command: 'rmt-cli sync' }
    warn _('importing data from SMT.')
    raise ImportException
  end
end
