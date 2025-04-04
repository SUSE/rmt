shared_context 'command without options' do
  let(:argv) { ['packages'] }

  around do |example|
    $stdin = StringIO.new("#{input}\n\n")
    example.run
    $stdin = STDIN
  end
end

shared_context 'command with dry run option' do
  let(:argv) { ['packages', '--dry-run'] }

  around do |example|
    $stdin = StringIO.new("#{input}\n\n")
    example.run
    $stdin = STDIN
  end
end

shared_context 'command with verbose mode' do
  let(:argv) { ['packages', '--verbose'] }

  around do |example|
    $stdin = StringIO.new("#{input}\n\n")
    example.run
    $stdin = STDIN
  end
end

shared_context 'command with dry run and verbose options' do
  let(:argv) { ['packages', '--dry-run', '--verbose'] }

  around do |example|
    $stdin = StringIO.new("#{input}\n\n")
    example.run
    $stdin = STDIN
  end
end

shared_context 'command with non-interactive mode' do
  let(:argv) { ['packages', '--non-interactive'] }
  let(:confirmation_prompt) { '' }
end

shared_context 'command with non-interactive and verbose options' do
  let(:argv) { ['packages', '--non-interactive', '--verbose'] }
  let(:confirmation_prompt) { '' }
end

shared_context 'mirror repositories' do
  before do
    mirrored_repos.each do |repo|
      FileUtils.mkdir_p(repo[:dir])
      FileUtils.cp_r(file_fixture(repo[:fixture]).to_s, mirror_dir)

      Dir.glob(File.join(repo[:dir], '**', '*.{rpm,drpm}')).each do |file|
        DownloadedFile.create(
          checksum: SecureRandom.uuid,
          checksum_type: :uuid,
          local_path: file,
          size: File.size(file)
        )
      end
    end
  end
end

shared_context 'mirror repositories with dangling files' do
  include_context 'mirror repositories'

  before do
    fresh_dangling = [fresh_dangling_list, 1.day.before(current_time).to_time]
    dangling       = [dangling_list,       2.days.before(current_time).to_time]

    [fresh_dangling, dangling].each do |list, time|
      list.files.each do |file|
        FileUtils.cp(File.join(mirror_dir, file[:fixture]).to_s, file[:file])
        File.utime(time, time, file[:file])
      end

      list.hardlinks.each do |file|
        File.link(File.join(mirror_dir, file[:fixture]).to_s, file[:file])
        File.utime(time, time, file[:file])
      end

      list.db_entries.each do |file|
        DownloadedFile.create(
          checksum: SecureRandom.uuid,
          checksum_type: :uuid,
          local_path: file[:file],
          size: File.size(file[:file])
        )
      end
    end
  end
end
