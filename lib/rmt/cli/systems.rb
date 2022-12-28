class RMT::CLI::Systems < RMT::CLI::Base
  # Amount of time after which a system is considered inactive. This is a
  # definition shared across projects. Check out the term on the glossary that
  # we maintain on scc-docs for more information
  # (https://github.com/SUSE/scc-docs/blob/master/projects/scc/architecture/glossary.md#inactive).
  INACTIVE = 3.months

  desc 'list', _('List registered systems.')
  option :limit, aliases: '-l', type: :numeric, default: 20, desc: _('Number of systems to display')
  option :all, aliases: '-a', type: :boolean, desc: _('List all registered systems')
  option :proxy_byos, type: :boolean, desc: _('Filter BYOS systems using RMT as a proxy')
  option :csv, type: :boolean, desc: _('Output data in CSV format')

  def list
    systems = System.order(id: :desc)
    systems = systems.where(proxy_byos: true) if options.proxy_byos
    systems = systems.limit(options.limit) unless options.all

    if System.count == 0
      warn _('There are no systems registered to this RMT instance.')
    elsif options.csv
      puts RMT::CLI::Decorators::SystemDecorator.csv_headers
      systems.in_batches(order: :desc, load: true) do |relation|
        decorator = RMT::CLI::Decorators::SystemDecorator.new(relation)
        puts decorator.to_csv(batch: true)
      end
    else
      rows = []
      systems.in_batches(order: :desc, load: true) do |relation|
        rows += relation
      end
      decorator = RMT::CLI::Decorators::SystemDecorator.new(rows)
      puts decorator.to_table

      unless options.all
        puts _("Showing last %{limit} registrations. Use the '--all' option to see all registered systems.") % {
          limit: options.limit
        }
      end
    end
  end
  map 'ls' => :list

  desc 'scc-sync', _('Forward registered systems data to SCC')
  def scc_sync
    RMT::SCC.new(options).sync_systems
  end

  desc 'remove TARGET', _('Removes a system and its activations from RMT')
  long_desc <<~REMOVE
    #{_('Removes a system and its activations from RMT.')}

    #{_('To target a system for removal, use the command "%{command}" for a list of systems with their corresponding logins.') % { command: 'rmt-cli systems list' }}

    #{_('Examples')}:

    $ rmt-cli systems remove SCC_e740f34145b84523a184ace764d0d597
  REMOVE
  def remove(target)
    target_system = System.find_by!(login: target)
    RegistrationSharing.save_for_sharing(target_system) if defined? RegistrationSharing
    target_system.destroy!
    puts _('Successfully removed system with login %{login}.') % { login: target }
  rescue ActiveRecord::RecordNotDestroyed
    raise RMT::CLI::Error.new(_('System with login %{login} cannot be removed.') % { login: target })
  rescue ActiveRecord::RecordNotFound
    raise RMT::CLI::Error.new(_('System with login %{login} not found.') % { login: target })
  end
  map 'rm' => :remove

  desc 'purge', _('Removes inactive systems')
  option :before, aliases: '-b', type: :string, desc: _('Remove systems before the given date (format: "<year>-<month>-<day>")')
  option :confirmation, type: :boolean, default: true, desc: _('Ask for confirmation or do not ask for confirmation and require no user interaction')
  long_desc <<~PURGE
    #{_('Removes old systems and their activations if they are inactive.')}

    #{_('By default, inactive systems are those that have not contacted in any way with RMT for the past 3 months. You can override this with the \'-b / --before\' flag.')}

    #{_('The command will list you the candidates for removal and will ask for confirmation. You can tell this subcommand to go ahead without asking with the \'--no-confirmation\' flag.')}

    #{_('Examples')}:

    $ rmt-cli systems purge --no-confirmation --before 2022-02-28
  PURGE
  def purge
    ask, before = purge_options
    systems = System.where('last_seen_at < ?', before)

    decorator = RMT::CLI::Decorators::SystemDecorator.new(systems)

    if systems.empty?
      warn _("No systems to be purged on this RMT instance. All systems have contacted RMT after #{before}.")
      return
    else
      puts decorator.to_table
    end

    return if ask && !yesno(_('Do you want to delete these systems?'))

    systems.destroy_all
    puts "Purged systems that have not contacted this RMT since #{before}."
  end

  protected

  # Returns true if the user answered positively the given question, false
  # otherwise.
  def yesno(msg)
    loop do
      print "#{msg} (#{_('y')}/#{_('n')}) "
      prompt = $stdin.gets.chomp.downcase

      return true if prompt == _('y')
      return false if prompt == _('n')

      warn "#{_('Please, answer')} #{_('y')}/#{_('n')}"
    end
  end

  # Returns the validated options expected by the `purge` subcommand.
  def purge_options
    dt = options.before.to_s.to_datetime || INACTIVE.ago

    [options.confirmation, dt.strftime('%F')]
  rescue ArgumentError
    raise RMT::CLI::Error.new(_("The given date does not follow a proper format. Ensure it follows this format '<year>-<month>-<day>'."))
  end
end
