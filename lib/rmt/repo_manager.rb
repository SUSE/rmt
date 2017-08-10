require 'rmt'
require 'optparse'

class RMT::RepoManager

  def initialize(argv, out = nil)
    @argv = argv
    @options = {}
    @affected_repos = 0
    @out = out || StringIO.new
  end

  def parse_options
    opt_parser = OptionParser.new do |opts|
      opts.banner = 'Usage: rmt-repos [options]'

      opts.separator ''

      opts.on_tail('-h', '--help', 'Show this message') do
        @out.puts opts
        exit
      end

      opts.on_tail('-v', '--version', 'Show version') do
        @out.puts RMT::VERSION
        exit
      end

      opts.on('-a', '--all', 'List all repositories') do |all|
        @options[:all] = all
      end

      opts.on('-e', '--enable', 'Enable the repository') do |opt|
        @options[:enable] = opt
      end

      opts.on('-d', '--disable', 'Disable the repository') do |opt|
        @options[:disable] = opt
      end

      opts.on('-r', '--repository REPOSITORY_ID', 'Repository by ID to enable/disable') do |opt|
        @options[:repository] = opt
      end

      opts.on('-p', '--product PRODUCT', 'Product string to enable/disable in "identifier/version/arch" format') do |opt|
        @options[:product] = true
        @options[:identifier], @options[:version], @options[:arch] = opt.split('/')
        unless (@options[:identifier] && @options[:version])
          raise 'Please specify product string in "identifier/version/arch" format'
        end
      end

      opts.on('-x', '--exclude-optional', 'Exclude non-mandatory repositories') do |opt|
        @options[:exclude_optional] = opt
      end
    end

    opt_parser.parse!(@argv)
  end

  def execute!
    parse_options

    if (@options[:enable] || @options[:disable])
      mirroring_enabled = (@options[:enable]) ? true : false

      if (@options[:repository])
        change_repository_mirroring(mirroring_enabled, @options[:repository])
      elsif (@options[:product])
        change_product_mirroring(mirroring_enabled, @options[:identifier], @options[:version], @options[:arch])
      else
        raise 'Need to specify which repository to enable/disable!'
      end

      @out.puts "#{@affected_repos} repo(s) successfully #{mirroring_enabled ? 'enabled' : 'disabled'}"
    else
      list_repositories
    end
  end

  protected

  def change_repository_mirroring(mirroring_enabled, repository_id)
    repository = Repository.find(repository_id)
    repository.mirroring_enabled = mirroring_enabled
    repository.save!
    @affected_repos += 1
  end

  def change_product_mirroring(mirroring_enabled, identifier, version, arch = nil)
    conditions = { identifier: identifier, version: version }
    conditions[:arch] = arch if arch

    products = Product.where(conditions).all
    products.each do |product|
      conditions = {}
      conditions[:enabled] = true if (@options[:exclude_optional])
      @affected_repos += product.repositories.where(conditions).update_all(mirroring_enabled: mirroring_enabled)
    end
  end

  def list_repositories
    conditions = {}
    conditions[:mirroring_enabled] = true unless (@options[:all])

    rows = []
    repositories = Repository.where(conditions)
    repositories.all.each do |repository|
      rows << [ repository.id, repository.name, repository.distro_target, repository.description, repository.mirroring_enabled ]
    end

    @out.puts Terminal::Table.new headings: %w[ID Name Target Description Mirror?], rows: rows
  end

end
