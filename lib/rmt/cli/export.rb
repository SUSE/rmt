class RMT::CLI::Export < RMT::CLI::Base

  desc 'data PATH', _('Store SCC data in files at given path')
  def data(path)
    path = needs_path(path, writable: true)
    RMT::SCC.new(options).export(path)
  end

  desc 'settings PATH', _('Store repository settings at given path')
  def settings(path)
    path = needs_path(path, writable: true)
    filename = File.join(path, 'repos.json')

    data = Repository.only_mirroring_enabled.inject([]) { |data, repo| data << { url: repo.external_url, auth_token: repo.auth_token.to_s } }
    File.write(filename, data.to_json)
    puts _('Settings saved at %{file}.') % { file: filename }
  end

  desc 'repos PATH', _('Mirror repos at given path')
  long_desc <<-REPOS
  #{_('Run this command on an online RMT.')}

  #{_("The specified PATH must contain a %{file} file. An offline RMT can create this file with the command '%{command}'.") % {
    file: 'repos.json',
    command: 'rmt-cli export settings'
  }}

   #{_('RMT will mirror the specified repositories in %{file} to PATH, usually a portable storage device.' % { file: 'repos.json' })}
  REPOS
  def repos(path)
    path = needs_path(path, writable: true)
    suma_product_tree = RMT::Mirror::SumaProductTree.new(mirroring_base_dir: path, logger: logger)

    begin
      suma_product_tree.mirror
    rescue RMT::Mirror::Exception => e
      logger.warn(_('Exporting SUSE Manager product tree failed: %{error_message}') % { error_message: e.message })
    end

    repos_file = File.join(path, 'repos.json')
    raise RMT::CLI::Error.new(_('%{file} does not exist.') % { file: repos_file }) unless File.exist?(repos_file)

    repos = JSON.parse(File.read(repos_file))
    repos.each do |repo_json|
      repo = Repository.find_by(external_url: repo_json['url'])

      begin
        configuration = {
          repository: repo,
          logger: logger,
          mirroring_base_dir: path,
          mirror_sources: RMT::Config.mirror_src_files?,
          is_airgapped: true
        }
        RMT::Mirror.new(**configuration).mirror_now
      rescue RMT::Mirror::Exception => e
        warn e.to_s
      end
    end
  end

end
