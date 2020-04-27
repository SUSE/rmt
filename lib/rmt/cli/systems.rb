class RMT::CLI::Systems < RMT::CLI::Base
  desc 'list', _('List registered systems.')
  option :limit, aliases: '-l', type: :numeric, default: 20, desc: _('Number of systems to display')
  option :all, aliases: '-a', type: :boolean, desc: _('List all registered systems')
  option :csv, type: :boolean, desc: _('Output data in CSV format')

  class SystemNotFoundException < StandardError; end
  class SystemNotDestroyedException < StandardError; end

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

  desc 'remove TARGET', _('Permanently removes system with all its subscriptions and products.')
  long_desc <<~REMOVE
    #{_('Permanently removes selected system by login with all its subscriptions and products by login.')}

    #{_('Examples')}:

    $ rmt-cli systems remove uniqueLogin
  REMOVE
  def remove(target)
    purge_system(target)
  end

  protected

  def purge_system(target)
    system = find_system(target)
    destroy_system!(system)
    puts _('Successfully removed system with login %{login}') % { login: target }
  rescue SystemNotFoundException, SystemNotDestroyedException => e
    puts e.message
  end

  private

  def find_system(target)
    System.find_by!(login: target)
  rescue ActiveRecord::RecordNotFound
    raise SystemNotFoundException.new(_('System with login %{login} not found.') % { login: target })
  end

  def destroy_system!(system)
    system.destroy!
  rescue ActiveRecord::RecordNotDestroyed
    raise SystemNotDestroyedException.new(_('System with login %{login} cannot be removed.') % { login: system.login })
  end
end
