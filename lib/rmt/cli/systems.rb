class RMT::CLI::Systems < RMT::CLI::Base
  desc 'list', _('List registered systems.')
  option :limit, aliases: '-l', type: :numeric, default: 20, desc: _('Number of systems to display')
  option :all, aliases: '-a', type: :boolean, desc: _('List all registered systems')
  option :csv, type: :boolean, desc: _('Output data in CSV format')

  def list
    systems = (options.all ? System.all : System.limit(options.limit)).order(id: :desc)
    decorator = RMT::CLI::Decorators::SystemDecorator.new(systems)

    if systems.empty?
      warn _('There are no systems registered to this RMT instance.')
    elsif options.csv
      puts decorator.to_csv
    else
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
end
