require 'rails_helper'

class DanglingList
  attr_reader :files, :db_entries, :hardlinks

  def initialize(files: [], db_entries: [], hardlinks: [])
    @files = files
    @db_entries = db_entries
    @hardlinks = hardlinks
  end
end

RSpec.describe RMT::CLI::Clean do
  describe '#packages' do
    let(:command) { described_class.start(argv) }

    let(:tmp_dir) { Dir.mktmpdir }
    let(:mirror_dir) { File.join(tmp_dir, 'public', 'repo') }

    let(:current_time) { Time.zone.local(2021, 11, 10, 14, 20, 0) }

    let(:dummy_repo) do
      { fixture: 'dummy_repo', dir: File.join(mirror_dir, 'dummy_repo') }
    end
    let(:dummy_repo_with_src) do
      { fixture: 'dummy_repo_with_src', dir: File.join(mirror_dir, 'dummy_repo_with_src') }
    end
    let(:mirrored_repos) { [dummy_repo, dummy_repo_with_src] }
    let(:dangling_files) do
      {
        rpm1: {
          fixture: 'dummy_repo_with_src/x86_64/apples-0.0.2-lp151.2.1.x86_64.rpm',
          file: File.join(dummy_repo_with_src[:dir], 'x86_64', 'lemon-0.0.2-lp151.2.1.x86_64.rpm')
        },
        drpm1: {
          fixture: 'dummy_repo_with_src/x86_64/apples-0.0.1_0.0.2-lp151.2.1.x86_64.drpm',
          file: File.join(dummy_repo_with_src[:dir], 'x86_64', 'lemon-0.0.1_0.0.2-lp151.2.1.x86_64.drpm')
        },
        rpm2: {
          fixture: 'dummy_repo/apples-0.2-0.x86_64.rpm',
          file: File.join(dummy_repo[:dir], 'blueberry-0.2-0.x86_64.rpm')
        },
        drpm2: {
          fixture: 'dummy_repo/apples-0.1-0.x86_64.drpm',
          file: File.join(dummy_repo[:dir], 'blueberry-0.1-0.x86_64.drpm')
        },
        src1: {
          fixture: 'dummy_repo_with_src/src/oranges-0.0.1-lp151.1.1.src.rpm',
          file: File.join(dummy_repo_with_src[:dir], 'src', 'lemon-0.0.1-lp151.1.1.src.rpm')
        },
        src2: {
          fixture: 'dummy_repo_with_src/src/apples-0.0.2-lp151.2.1.src.rpm',
          file: File.join(dummy_repo_with_src[:dir], 'src', 'lemon-0.0.2-lp151.2.1.src.rpm')
        },
        rpm3: {
          fixture: 'dummy_repo/blueberry-0.2-0.x86_64.rpm',
          file: File.join(dummy_repo[:dir], 'strawberry-0.3-0.x86_64.rpm')
        },
        rpm4: {
          fixture: 'dummy_repo/blueberry-0.2-0.x86_64.rpm',
          file: File.join(dummy_repo[:dir], 'cranberry-0.4-0.x86_64.rpm')
        }
      }
    end

    let(:input) { 'yes' }
    let(:expected_output) do
      <<~OUTPUT
        \n\e[1mScanning the mirror directory for 'repomd.xml' files...\e[0m
        RMT found repomd.xml files: 2 files.
        Now, it will parse all repomd.xml files, search for dangling packages on disk and clean them.

        #{confirmation_prompt}#{expected_result_output}
      OUTPUT
    end
    let(:confirmation_prompt) do
      <<~OUTPUT
        \e[1mThis can take several minutes. Would you like to continue and clean dangling packages?\e[0m
          Only 'yes' will be accepted.
          \e[1mEnter a value:\e[0m\s
      OUTPUT
    end
    let(:dangling_list)       { DanglingList.new }
    let(:fresh_dangling_list) { DanglingList.new }

    shared_context 'default dangling files setup' do
      let(:dangling_list) do
        DanglingList.new(files: dangling_files.values_at(:rpm1, :drpm1, :rpm2, :drpm2),
                         db_entries: dangling_files.values_at(:rpm1, :rpm2, :drpm2))
      end

      let(:expected_result_output) do
        <<~OUTPUT.chomp
          \e[1mDirectory: #{dummy_repo[:dir]}\e[0m
          Cleaned 2 files (#{file_human_size(4038)}), 2 database entries.

          \e[1mDirectory: #{dummy_repo_with_src[:dir]}\e[0m
          Cleaned 2 files (#{file_human_size(10824)}), 1 database entry.

          #{'-' * 80}
          \e[32;1mTotal: cleaned 4 files (#{file_human_size(14862)}), 3 database entries.\e[0m
        OUTPUT
      end
    end

    around do |example|
      RMT.send(:remove_const, 'DEFAULT_MIRROR_DIR')
      RMT.const_set('DEFAULT_MIRROR_DIR', mirror_dir)
      FileUtils.mkdir_p(mirror_dir)
      Timecop.freeze(current_time) do
        example.run
      end
      FileUtils.rm_r(tmp_dir, secure: false)
    end

    context 'when no repomd files have been found' do
      let(:argv) { ['packages'] }
      let(:mirrored_repos) { [] }
      let(:expected_output) do
        <<~OUTPUT
          \n\e[1mScanning the mirror directory for 'repomd.xml' files...\e[0m
          \e[31;1mRMT found no repomd.xml files. Check if RMT is properly configured.\e[0m
        OUTPUT
      end

      include_examples 'prints to stdout'
    end

    context "when RMT asks for confirmation and user inputs text other than 'yes'" do
      let(:expected_result_output) { 'Clean cancelled.' }
      let(:input) { 'no' }

      include_context 'command without options'
      include_context 'mirror repositories'

      include_examples 'prints to stdout'
    end

    context 'when no dangling packages have been found' do
      let(:expected_result_output) { "\e[32;1mNo dangling packages have been found!\e[0m" }

      include_context 'mirror repositories'

      context 'and no options have been passed' do
        include_context 'command without options'

        include_examples 'prints to stdout'
        include_examples 'does not remove files'
        include_examples 'does not remove database entries'
      end

      context 'and --verbose option is set' do
        include_context 'command with verbose mode'

        include_examples 'prints to stdout'
        include_examples 'does not remove files'
        include_examples 'does not remove database entries'
      end

      context 'and --non-interactive option is set' do
        include_context 'command with non-interactive mode'

        let(:confirmation_prompt) { '' }

        include_examples 'prints to stdout'
        include_examples 'does not remove files'
        include_examples 'does not remove database entries'
      end
    end

    context 'when there are dangling packages and no options have been passed' do
      include_context 'default dangling files setup'
      include_context 'mirror repositories with dangling files'
      include_context 'command without options'

      include_examples 'prints to stdout'
      include_examples 'removes files'
      include_examples 'removes database entries'
    end

    context 'when there are dangling packages and --dry-run option is set' do
      include_context 'default dangling files setup'
      include_context 'mirror repositories with dangling files'
      include_context 'command with dry run option'

      include_examples 'prints to stdout'
      include_examples 'does not remove files'
      include_examples 'does not remove database entries'
    end

    context 'when there are dangling packages and --non-interactive option is set' do
      include_context 'default dangling files setup'
      include_context 'mirror repositories with dangling files'
      include_context 'command with non-interactive mode'

      include_examples 'prints to stdout'
      include_examples 'removes files'
      include_examples 'removes database entries'
    end

    context 'when there are dangling packages and --verbose option is set' do
      let(:dangling_list) do
        DanglingList.new(files: dangling_files.values_at(:rpm1, :drpm1, :rpm2, :drpm2),
                         db_entries: dangling_files.values_at(:rpm1, :rpm2, :drpm2))
      end
      let(:expected_result_output) do
        <<~OUTPUT.chomp
          \e[1mDirectory: #{dummy_repo[:dir]}\e[0m
            Cleaned 'blueberry-0.1-0.x86_64.drpm' (#{file_human_size(2088)}), 1 database entry.
            Cleaned 'blueberry-0.2-0.x86_64.rpm' (#{file_human_size(1950)}), 1 database entry.
          Cleaned 2 files (#{file_human_size(4038)}), 2 database entries.

          \e[1mDirectory: #{dummy_repo_with_src[:dir]}\e[0m
            Cleaned 'x86_64/lemon-0.0.1_0.0.2-lp151.2.1.x86_64.drpm' (#{file_human_size(3544)}), 0 database entries.
            Cleaned 'x86_64/lemon-0.0.2-lp151.2.1.x86_64.rpm' (#{file_human_size(7280)}), 1 database entry.
          Cleaned 2 files (#{file_human_size(10824)}), 1 database entry.

          #{'-' * 80}
          \e[32;1mTotal: cleaned 4 files (#{file_human_size(14862)}), 3 database entries.\e[0m
        OUTPUT
      end

      include_context 'mirror repositories with dangling files'
      include_context 'command with verbose mode'

      include_examples 'prints to stdout'
      include_examples 'removes files'
      include_examples 'removes database entries'
    end

    context 'when there are dangling packages and some are source packages' do
      let(:dangling_list) do
        DanglingList.new(db_entries: dangling_files.values_at(:rpm1, :rpm2, :drpm2, :src2),
                         files: dangling_files.values_at(:src1, :src2, :rpm1, :drpm1, :rpm2, :drpm2))
      end
      let(:expected_result_output) do
        <<~OUTPUT.chomp
          \e[1mDirectory: #{dummy_repo[:dir]}\e[0m
            Cleaned 'blueberry-0.1-0.x86_64.drpm' (#{file_human_size(2088)}), 1 database entry.
            Cleaned 'blueberry-0.2-0.x86_64.rpm' (#{file_human_size(1950)}), 1 database entry.
          Cleaned 2 files (#{file_human_size(4038)}), 2 database entries.

          \e[1mDirectory: #{dummy_repo_with_src[:dir]}\e[0m
            Cleaned 'src/lemon-0.0.1-lp151.1.1.src.rpm' (#{file_human_size(7518)}), 0 database entries.
            Cleaned 'src/lemon-0.0.2-lp151.2.1.src.rpm' (#{file_human_size(7528)}), 1 database entry.
            Cleaned 'x86_64/lemon-0.0.1_0.0.2-lp151.2.1.x86_64.drpm' (#{file_human_size(3544)}), 0 database entries.
            Cleaned 'x86_64/lemon-0.0.2-lp151.2.1.x86_64.rpm' (#{file_human_size(7280)}), 1 database entry.
          Cleaned 4 files (#{file_human_size(25870)}), 2 database entries.

          #{'-' * 80}
          \e[32;1mTotal: cleaned 6 files (#{file_human_size(29908)}), 4 database entries.\e[0m
        OUTPUT
      end

      include_context 'mirror repositories with dangling files'
      include_context 'command with verbose mode'

      include_examples 'prints to stdout'
      include_examples 'removes files'
      include_examples 'removes database entries'
    end

    context 'when there are dangling packages and some are less than 2-days-old' do
      let(:dangling_list) do
        DanglingList.new(files: dangling_files.values_at(:rpm2, :drpm2),
                         db_entries: dangling_files.values_at(:rpm2))
      end
      let(:fresh_dangling_list) do
        DanglingList.new(files: dangling_files.values_at(:rpm1, :drpm1),
                         db_entries: dangling_files.values_at(:rpm1))
      end
      let(:expected_result_output) do
        <<~OUTPUT.chomp
          \e[1mDirectory: #{dummy_repo[:dir]}\e[0m
            Cleaned 'blueberry-0.1-0.x86_64.drpm' (#{file_human_size(2088)}), 0 database entries.
            Cleaned 'blueberry-0.2-0.x86_64.rpm' (#{file_human_size(1950)}), 1 database entry.
          Cleaned 2 files (#{file_human_size(4038)}), 1 database entry.

          #{'-' * 80}
          \e[32;1mTotal: cleaned 2 files (#{file_human_size(4038)}), 1 database entry.\e[0m
        OUTPUT
      end

      include_context 'mirror repositories with dangling files'
      include_context 'command with verbose mode'

      include_examples 'prints to stdout'
      include_examples 'removes files'
      include_examples 'removes database entries'
      include_examples 'does not remove fresh dangling files'
      include_examples 'does not remove database entries of fresh dangling files'
    end

    context 'when there are dangling packages and all of them are hardlinks' do
      let(:dangling_list) do
        DanglingList.new(db_entries: dangling_files.values_at(:rpm1, :rpm2, :drpm2, :src2),
                         hardlinks: dangling_files.values_at(:src1, :src2, :rpm1, :drpm1, :rpm2, :drpm2))
      end
      let(:expected_result_output) do
        <<~OUTPUT.chomp
        \e[1mDirectory: #{dummy_repo[:dir]}\e[0m
          Cleaned 'blueberry-0.1-0.x86_64.drpm' (#{file_human_size(0)}, hardlink), 1 database entry.
          Cleaned 'blueberry-0.2-0.x86_64.rpm' (#{file_human_size(0)}, hardlink), 1 database entry.
        Cleaned 2 files (#{file_human_size(0)}), 2 database entries.

        \e[1mDirectory: #{dummy_repo_with_src[:dir]}\e[0m
          Cleaned 'src/lemon-0.0.1-lp151.1.1.src.rpm' (#{file_human_size(0)}, hardlink), 0 database entries.
          Cleaned 'src/lemon-0.0.2-lp151.2.1.src.rpm' (#{file_human_size(0)}, hardlink), 1 database entry.
          Cleaned 'x86_64/lemon-0.0.1_0.0.2-lp151.2.1.x86_64.drpm' (#{file_human_size(0)}, hardlink), 0 database entries.
          Cleaned 'x86_64/lemon-0.0.2-lp151.2.1.x86_64.rpm' (#{file_human_size(0)}, hardlink), 1 database entry.
        Cleaned 4 files (#{file_human_size(0)}), 2 database entries.

        #{'-' * 80}
        \e[32;1mTotal: cleaned 6 files (#{file_human_size(0)}), 4 database entries.\e[0m
        OUTPUT
      end

      include_context 'mirror repositories with dangling files'
      include_context 'command with verbose mode'

      include_examples 'prints to stdout'
      include_examples 'removes files'
      include_examples 'removes database entries'
    end

    context 'when there are dangling packages and some hardlinks points to them' do
      let(:dangling_list) do
        DanglingList.new(files: dangling_files.values_at(:drpm1, :rpm2),
                         hardlinks: dangling_files.values_at(:src1, :drpm2, :rpm3, :rpm4),
                         db_entries: dangling_files.values_at(:rpm2, :drpm2, :rpm4))
      end
      let(:fresh_state_files) do
        DanglingList.new(files: dangling_files.values_at(:rpm1),
                         hardlinks: dangling_files.values_at(:src2),
                         db_entries: dangling_files.values_at(:rpm1, :src2))
      end
      let(:expected_result_output) do
        <<~OUTPUT.chomp
          \e[1mDirectory: #{dummy_repo[:dir]}\e[0m
            Cleaned 'blueberry-0.1-0.x86_64.drpm' (#{file_human_size(0)}, hardlink), 1 database entry.
            Cleaned 'blueberry-0.2-0.x86_64.rpm' (#{file_human_size(0)}, hardlink), 1 database entry.
            Cleaned 'cranberry-0.4-0.x86_64.rpm' (#{file_human_size(0)}, hardlink), 1 database entry.
            Cleaned 'strawberry-0.3-0.x86_64.rpm' (#{file_human_size(1950)}), 0 database entries.
          Cleaned 4 files (#{file_human_size(1950)}), 3 database entries.

          \e[1mDirectory: #{dummy_repo_with_src[:dir]}\e[0m
            Cleaned 'src/lemon-0.0.1-lp151.1.1.src.rpm' (#{file_human_size(0)}, hardlink), 0 database entries.
            Cleaned 'x86_64/lemon-0.0.1_0.0.2-lp151.2.1.x86_64.drpm' (#{file_human_size(3544)}), 0 database entries.
          Cleaned 2 files (#{file_human_size(3544)}), 0 database entries.

          #{'-' * 80}
          \e[32;1mTotal: cleaned 6 files (#{file_human_size(5494)}), 3 database entries.\e[0m
        OUTPUT
      end

      include_context 'mirror repositories with dangling files'
      include_context 'command with verbose mode'

      include_examples 'prints to stdout'
      include_examples 'removes files'
      include_examples 'removes database entries'
      include_examples 'does not remove fresh dangling files'
      include_examples 'does not remove database entries of fresh dangling files'

      context '--dry-run options is set' do
        include_context 'command with dry run and verbose options'

        include_examples 'prints to stdout'
        include_examples 'does not remove files'
        include_examples 'does not remove database entries'
        include_examples 'does not remove fresh dangling files'
        include_examples 'does not remove database entries of fresh dangling files'
      end
    end
  end
end
