class RMT::CLI::Systems < RMT::CLI::Base
  # Amount of time after which a system is considered inactive. This is a
  # definition shared across projects. Check out the term on the glossary that
  # we maintain on scc-docs for more information
  # (https://github.com/SUSE/scc-docs/blob/master/projects/scc/architecture/glossary.md#inactive).
  INACTIVE = 3.months
  # number of systems rendered by the table
  # or handled by the batch loop
  # higher numbers like 1000, 500, 100 and even 50
  # user can see the table waiting to be populated
  VERBOSE_BATCH_SIZE = 20
  DELETE_BATCH_SIZE = 500

  desc 'list', _('List registered systems.')
  option :limit, aliases: '-l', type: :numeric, default: 20, desc: _('Number of systems to display')
  option :all, aliases: '-a', type: :boolean, desc: _('List all registered systems')
  option :proxy_byos_mode, type: :boolean, desc: _('Filter BYOS systems using RMT as a proxy')
  option :csv, type: :boolean, desc: _('Output data in CSV format')

  def list
    systems = System.all
    systems = systems.where(proxy_byos_mode: :byos) if options.proxy_byos_mode
    systems = systems.limit(options.limit).order(id: :desc) unless options.all

    if System.count == 0
      warn _('There are no systems registered to this RMT instance.')
    elsif options.csv
      puts RMT::CLI::Decorators::SystemDecorator.csv_headers
      systems.in_batches(order: :desc, load: true) do |relation|
        decorator = RMT::CLI::Decorators::SystemDecorator.new(relation)
        puts decorator.to_csv(batch: true)
      end
    else
      systems_ids = systems.pluck(:id)
      systems_ids = systems_ids.reverse if options.all

      print_rows(systems_ids)
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
  option :verbose, aliases: '-v', type: :boolean, default: false, desc: _('Show system details')
  long_desc <<~PURGE
    #{_('Removes old systems and their activations if they are inactive.')}

    #{_('By default, inactive systems are those that have not contacted RMT in any way in the past 3 months. You can override this with the \'-b / --before\' flag.')}

    #{_('The command will list the candidates for removal and will ask for confirmation. You can tell this subcommand to go ahead without asking with the \'--no-confirmation\' flag.')}

    #{_('Examples')}:

    $ rmt-cli systems purge --no-confirmation --before 2022-02-28
  PURGE
  def purge
    ask, before, verbose = purge_options
    if verbose
      systems, fetch_ok = get_all_matches(before)
      if systems.empty?
        warn _("No systems to be purged on this RMT instance. All systems have contacted RMT after #{before}.") if fetch_ok
        return
      end
      print_rows(systems)
    end
    return if ask && !yesno(_('Do you want to delete all the matching systems?'))

    delete_ok = verbose ? delete_systems(systems) : delete_all_matching_systems(before)
    if delete_ok.present? && delete_ok.zero?
      warn _("No systems to be purged on this RMT instance. All systems have contacted RMT after #{before}.")
      return
    end
    message = delete_ok ? 'all' : 'some'
    puts "Purged #{message} systems that have not contacted this RMT since #{before}."
    puts "Systems that have not contacted this RMT since #{before} may still be in this RMT" unless fetch_ok.presence || delete_ok.presence
  end

  protected

  def delete_all_matching_systems(before)
    n_systems_destroyed = 0
    attempts = 0
    begin
      attempts += 1
      System.where('last_seen_at < ?', before).in_batches(of: DELETE_BATCH_SIZE) do |batch|
        n_systems_destroyed += batch.length
        batch.destroy_all
        puts "#{n_systems_destroyed} systems destroyed"
      end
      n_systems_destroyed
    rescue StandardError => e
      if attempts < 3
        puts "Error while purging systems: #{e.message}. Retrying in 5 seconds (#{attempts}/3)"
        sleep 5
        retry
      end
      puts "Could not delete all systems last seen before #{before}: #{e.message}"
    end
  end

  def get_all_matches(before)
    systems_matched = []
    System.where('last_seen_at < ?', before).in_batches(of: DELETE_BATCH_SIZE, order: :desc) do |batch|
      systems_matched += batch.pluck(:id)
      puts "#{systems_matched.length} systems last seen before #{before}"
    end
    [systems_matched, true]
  rescue StandardError => e
    puts "Could not get all systems last seen before #{before}: #{e.message}"
    [systems_matched, false]
  end

  def delete_systems(systems)
    attempts = 0
    deleted_systems = []
    begin
      attempts += 1
      systems.each_slice(DELETE_BATCH_SIZE) do |sliced_systems_ids|
        System.where(id: sliced_systems_ids).in_batches(of: DELETE_BATCH_SIZE).destroy_all
        deleted_systems += sliced_systems_ids
        n_deleted = (systems.length - deleted_systems.length > 0) ? (systems - deleted_systems).length : systems.length
        puts "#{n_deleted} systems to be deleted"
      end
      deleted_systems.length
    rescue StandardError => e
      systems -= deleted_systems
      if attempts < 3
        puts "Error while purging systems: #{e.message}. Attempt #{attempts}/3, retrying in 5 seconds"
        sleep 5
        retry
      else
        puts "Error while purging the systems: #{e.message}, #{systems.length} systems could not be removed"
      end
    end
  end

  def print_rows(systems)
    column_widths = max_column_widths
    style = {}
    systems_first = systems.first
    systems_last = systems.last
    systems.each_slice(VERBOSE_BATCH_SIZE) do |sliced_systems_ids|
      # avoid N + 1 queries when decorator gets the product from the activation
      sliced_systems = System.includes(:activations).where(id: sliced_systems_ids).order(id: :desc)
      decorator_systems = RMT::CLI::Decorators::SystemDecorator.new(sliced_systems)
      border_bottom = sliced_systems_ids.last == systems_last
      first_row = sliced_systems_ids.first == systems_first
      style[:border_bottom] = border_bottom
      style[:border_top] = first_row
      puts decorator_systems.to_table(add_headers: first_row, style: style, width: column_widths)
    end
  end

  def max_column_widths
    # we need the max value for each column as the table rendering
    # split the width for each cell equally
    # this makes the rendered table to add extra spaces for some columns
    # while it is not ideal, we have not found a better way
    date_length = Time.now.utc.to_s.length
    max_hostname = ActiveRecord::Base.connection.execute('SELECT max(length(hostname)) FROM systems').to_a.flatten.first
    max_login = ActiveRecord::Base.connection.execute('SELECT max(length(login)) FROM systems').to_a.flatten.first
    max_identifier = ActiveRecord::Base.connection.execute('SELECT max(length(identifier)) FROM products').to_a.flatten.first
    max_arch = ActiveRecord::Base.connection.execute('SELECT max(length(arch)) FROM products').to_a.flatten.first
    # max product width is the length of max identifier/ max version/ max arch
    product = max_identifier + 4 + max_arch + 2
    [max_login, max_hostname, date_length, date_length, product]
  end

  # Returns true if the user answered positively the given question, false
  # otherwise.
  def yesno(msg)
    loop do
      print "#{msg} (#{_('y')}/#{_('n')}) "
      prompt = $stdin.gets.chomp.downcase

      return true if prompt == _('y')
      return false if prompt == _('n')

      warn "#{_('Please answer')} #{_('y')}/#{_('n')}"
    end
  end

  # Returns the validated options expected by the `purge` subcommand.
  def purge_options
    dt = options.before.to_s.to_datetime || INACTIVE.ago

    [options.confirmation, dt.strftime('%F'), options.verbose]
  rescue ArgumentError
    raise RMT::CLI::Error.new(_("The given date does not follow the proper format. Ensure it follows this format '<year>-<month>-<day>'."))
  end
end
