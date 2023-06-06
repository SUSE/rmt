class RMT::CLI::Clean < RMT::CLI::Base
  STALE_FILE_MINIMUM_AGE = 48 * 60 * 60 # 2 days (in seconds)
  CleanedFile = Struct.new(:path, :file_size, :db_entries, keyword_init: true).freeze

  desc 'packages', _('Clean stale package files, based on current repository data.')
  option :non_interactive, aliases: '-n', type: :boolean,
    desc: _('Do not ask anything, use default answers automatically. Default: false')
  option :dry_run, type: :boolean,
    desc: _('Run the clean process without actually removing files.')
  option :verbose, aliases: '-v', type: :boolean,
    desc: _('List files during the cleaning process.')
  long_desc _(
    <<~PACKAGES
    Clean stale package files, based on current repository metadata.

    This command scans the mirror directory for 'repomd.xml' files, parse the
    metadata files, and compare their content with files on disk. Files not
    listed in the metadata and at least 2-days-old are considered stale.

    Then, it removes all stale files from disk and any associated database entries.
    PACKAGES
  )

  def packages
    print "\n\e[1m"
    print _("Scanning the mirror directory for 'repomd.xml' files...")
    print "\e[0m\n"

    repomd_files = Dir.glob(File.join(RMT::DEFAULT_MIRROR_DIR, '**', 'repomd.xml'))

    repomd_count = repomd_files.count
    if repomd_count == 0
      print "\e[31;1m"
      print _('RMT found no repomd.xml files. Check if RMT is properly configured.')
      print "\e[0m\n"

      return
    end

    repomd_count_text = file_count_text(repomd_count)
    puts _('RMT found repomd.xml files: %{repomd_count}.') % { repomd_count: repomd_count_text }
    puts _('Now, it will parse all repomd.xml files, search for stale packages on disk and clean them.')

    unless options.non_interactive
      print "\n\e[1m"
      print _('This can take several minutes. Would you like to continue and clean stale packages?')
      print "\e[0m\n\s\s"
      print _("Only '%{input}' will be accepted.") % { input: _('yes') }
      print "\n\s\s\e[1m"
      print _('Enter a value:')
      print "\e[0m\s"

      input = $stdin.gets.to_s.strip
      if input != _('yes')
        puts "\n" + _('Clean cancelled.')
        return
      end
    end

    report = run_package_clean(repomd_files)

    if report[:total_cleaned_count] == 0
      print "\n\e[32;1m"
      print _('No stale packages have been found!')
      print "\e[0m\n"

      return
    end

    puts "\n#{'-' * 80}"
    print "\e[32;1m"
    print _('Total: cleaned %{total_count} (%{total_size}), %{total_db_entries}.') % {
      total_count: file_count_text(report[:total_cleaned_count]),
      total_size: ActiveSupport::NumberHelper.number_to_human_size(report[:total_cleaned_size]),
      total_db_entries: db_entries_text(report[:total_cleaned_db_entries])
    }
    print "\e[0m\n"
  end

  private

  def run_package_clean(repomd_files)
    dirs_with_stale_files = repomd_files.lazy.map do |repomd_file|
      repo_base_dir = File.absolute_path(File.join(File.dirname(repomd_file), '..'))
      stale_candidates = stale_candidates_list(repo_base_dir, repomd_file)

      next nil if stale_candidates.empty?

      [repo_base_dir, stale_candidates]
    end.reject(&:nil?)

    stats = dirs_with_stale_files.map do |(repo_base_dir, stale_packages)|
      cleaned_files = clean_stale_packages(stale_packages)

      next nil if cleaned_files.empty?

      print "\n\e[1m"
      print _('Directory: %{dir}') % { dir: repo_base_dir }
      print "\e[0m\n"

      quoted_repo_base_dir = Regexp.quote(repo_base_dir)
      if options.verbose
        cleaned_files.each do |file|
          puts "\s\s" + (
            _("Cleaned '%{file_name}' (%{file_size}), %{db_entries}.") % {
              file_name: file.path.gsub(%r{^#{quoted_repo_base_dir}/?}, ''),
              file_size: ActiveSupport::NumberHelper.number_to_human_size(file.file_size),
              db_entries: db_entries_text(file.db_entries)
            }
          )
        end
      end

      cleaned_files_count = cleaned_files.count
      cleaned_files_size = cleaned_files.sum(&:file_size)
      cleaned_db_entries = cleaned_files.sum(&:db_entries)

      puts _('Cleaned %{file_count_text} (%{total_size}), %{db_entries}.') % {
        file_count_text: file_count_text(cleaned_files_count),
        total_size: ActiveSupport::NumberHelper.number_to_human_size(cleaned_files_size),
        db_entries: db_entries_text(cleaned_db_entries)
      }

      [cleaned_files_count, cleaned_files_size, cleaned_db_entries]
    end.reject(&:nil?)

    total_cleaned_count, total_cleaned_size, total_cleaned_db_entries =
      stats.force.transpose.map(&:sum)

    {
      total_cleaned_size: total_cleaned_size.to_i,
      total_cleaned_count: total_cleaned_count.to_i,
      total_cleaned_db_entries: total_cleaned_db_entries.to_i
    }
  end

  def stale_candidates_list(repo_base_dir, repomd_file)
    expected_packages = parse_packages_data(repomd_file, repo_base_dir)
      .map { |file| File.join(repo_base_dir, file.location) }.sort

    actual_packages = Dir.glob(File.join(repo_base_dir, '**', '*.{rpm,drpm}')).sort

    (actual_packages - expected_packages).sort
  end

  def parse_packages_data(repomd_file, repo_base_dir)
    metadata_files = RepomdParser::RepomdXmlParser.new(repomd_file).parse

    xml_parsers = { deltainfo: RepomdParser::DeltainfoXmlParser,
                    primary: RepomdParser::PrimaryXmlParser }

    metadata_files.reduce([]) do |acc, metadata|
      next acc unless xml_parsers.key?(metadata.type)

      metadata_path = File.join(repo_base_dir, metadata.location)
      acc << xml_parsers[metadata.type].new(metadata_path).parse
    end.flatten
  end

  def clean_stale_packages(packages)
    packages.map do |file|
      next nil unless File.exist?(file)

      file_stat = File.stat(file)
      next nil if (Time.current - file_stat.mtime) < STALE_FILE_MINIMUM_AGE

      db_entries = DownloadedFile.where(local_path: file)

      unless options.dry_run
        FileUtils.rm(file)
        db_entries = db_entries.destroy_all
      end

      CleanedFile.new(path: file, file_size: file_stat.size, db_entries: db_entries.count)
    end.reject(&:nil?)
  end

  def file_count_text(count)
    n_('%{count} file', '%{count} files', count) % { count: count }
  end

  def db_entries_text(count)
    n_('%{db_entries} database entry', '%{db_entries} database entries', count) % { db_entries: count }
  end
end
