require 'rails_helper'

RSpec.describe RMT::CLI::Repos do
  describe '#clean' do
    let(:repository_1) { create :repository, mirroring_enabled: false }
    let(:repository_2) { create :repository, mirroring_enabled: false }
    let(:repository_3) { create :repository, mirroring_enabled: true }

    let(:argv) { ['clean'] }
    let(:input) { 'yes' }
    let(:dir) { Dir.mktmpdir }
    let(:repo_1_path) { File.join(dir, repository_1.local_path) }
    let(:repo_2_path) { File.join(dir, repository_2.local_path) }
    let(:repo_3_path) { File.join(dir, repository_3.local_path) }
    let(:total_removed_file_size) do
      Repository.where(mirroring_enabled: false).map(&:local_path).reduce(0) do |sum, repo_path|
        local_path = File.join(dir, repo_path)
        sum + DownloadedFile.where('local_path LIKE ?', "#{local_path}%").sum(:file_size)
      end
    end

    let(:command) do
      described_class.start(argv)
    end

    let(:expected_output) do
      <<-OUTPUT
RMT found locally mirrored files from the following repositories which are not marked to be mirrored:

\e[31m#{repository_1.description}
#{repository_2.description}

\e[0m\e[1mWould you like to continue and remove the locally mirrored files of these repositories?
\e[22m\s\sOnly 'yes' will be accepted.

  \e[1mEnter a value:\e[22m\s\s
Deleting locally mirrored files from repository '#{repository_1.description}'...
Deleting locally mirrored files from repository '#{repository_2.description}'...

\e[32mClean finished. An estimated #{ActiveSupport::NumberHelper.number_to_human_size(total_removed_file_size)} was removed.\e[0m
      OUTPUT
    end

    before do
      RMT.send(:remove_const, 'DEFAULT_MIRROR_DIR')
      RMT.const_set('DEFAULT_MIRROR_DIR', dir)
      FileUtils.mkdir_p(repo_1_path)
      FileUtils.mkdir_p(repo_2_path)
      FileUtils.mkdir_p(repo_3_path)
      [repo_1_path, repo_2_path, repo_3_path].each { |path| create_repository_file(path) }
      $stdin = StringIO.new("#{input}\n")
    end

    after do
      FileUtils.rm_r(repo_1_path) if Dir.exist?(repo_1_path)
      FileUtils.rm_r(repo_2_path) if Dir.exist?(repo_2_path)
      FileUtils.rm_r(repo_3_path) if Dir.exist?(repo_3_path)
      $stdin = STDIN
    end

    it 'delete downloaded files for non-mirrored repositories' do
      expect { command }.to output(expected_output).to_stdout.and output('').to_stderr

      expect(DownloadedFile.where('local_path LIKE ?', "#{repo_1_path}%").count).to eq(0)
      expect(DownloadedFile.where('local_path LIKE ?', "#{repo_2_path}%").count).to eq(0)
      expect(DownloadedFile.where('local_path LIKE ?', "#{repo_3_path}%").count).to eq(1)
    end

    it 'deletes repository non-mirrored repository directories' do
      expect { command }.to output(expected_output).to_stdout.and output('').to_stderr

      expect(Dir.exist?(repo_1_path)).to be(false)
      expect(Dir.exist?(repo_2_path)).to be(false)
      expect(Dir.exist?(repo_3_path)).to be(true)
    end

    context 'cancelled task' do
      let(:input) { 'no' }
      let(:expected_output) do
        <<-OUTPUT
RMT found locally mirrored files from the following repositories which are not marked to be mirrored:

\e[31m#{repository_1.description}
#{repository_2.description}

\e[0m\e[1mWould you like to continue and remove the locally mirrored files of these repositories?
\e[22m\s\sOnly 'yes' will be accepted.

\s\s\e[1mEnter a value:\e[22m\s\s
Clean cancelled.
        OUTPUT
      end

      it 'does not delete repository directories when cancelled' do
        expect { command }.to output(expected_output).to_stdout.and output('').to_stderr

        expect(Dir.exist?(repo_1_path)).to be(true)
        expect(Dir.exist?(repo_2_path)).to be(true)
        expect(Dir.exist?(repo_3_path)).to be(true)
      end

      it 'does not delete downloaded files when cancelled' do
        expect { command }.to output(expected_output).to_stdout.and output('').to_stderr

        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_1_path}%").count).to eq(1)
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_2_path}%").count).to eq(1)
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_3_path}%").count).to eq(1)
      end
    end

    context 'all repositories are mirrored' do
      let(:repository_1) { create :repository, mirroring_enabled: true }
      let(:repository_2) { create :repository, mirroring_enabled: true }
      let(:repository_3) { create :repository, mirroring_enabled: true }
      let(:expected_output) do
        <<-OUTPUT
RMT only found locally mirrored files of repositories that are marked to be mirrored.
        OUTPUT
      end

      it 'does not delete downloaded files when the repositories are marked to be mirrored' do
        expect { command }.to output(expected_output).to_stdout.and output('').to_stderr

        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_1_path}%").count).to eq(1)
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_2_path}%").count).to eq(1)
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_3_path}%").count).to eq(1)
      end

      it 'does not delete repositories from the disk when they are marked to be mirrored' do
        expect { command }.to output(expected_output).to_stdout.and output('').to_stderr

        expect(Dir.exist?(repo_1_path)).to be(true)
        expect(Dir.exist?(repo_2_path)).to be(true)
        expect(Dir.exist?(repo_3_path)).to be(true)
      end
    end

    context 'with -y' do
      let(:argv) { ['clean', '-y'] }
      let(:input) { 'no' }

      it 'delete downloaded files for non-mirrored repositories' do
        expect { command }.to output(expected_output).to_stdout.and output('').to_stderr
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_1_path}%").count).to eq(0)
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_2_path}%").count).to eq(0)
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_3_path}%").count).to eq(1)
      end
    end

    context 'with --no-confirm' do
      let(:argv) { ['clean', '--no-confirm'] }
      let(:input) { 'no' }

      it 'delete downloaded files for non-mirrored repositories' do
        expect { command }.to output(expected_output).to_stdout.and output('').to_stderr
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_1_path}%").count).to eq(0)
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_2_path}%").count).to eq(0)
        expect(DownloadedFile.where('local_path LIKE ?', "#{repo_3_path}%").count).to eq(1)
      end
    end
  end

  describe '#enable' do
    subject(:repository) { create :repository, :with_products }

    let(:command) do
      repository
      described_class.start(argv)
      repository.reload
    end

    context 'with multiple ids' do
      let(:repository_2) { create :repository, :with_products }
      let(:repository_3) { create :repository, :with_products }
      let(:argv) { ['enable', repository.friendly_id, repository_2.friendly_id, repository_3.friendly_id] }
      let(:expected_output) do
        <<-OUTPUT
Repository by ID #{repository.friendly_id} successfully enabled.
Repository by ID #{repository_2.friendly_id} successfully enabled.
Repository by ID #{repository_3.friendly_id} successfully enabled.
        OUTPUT
      end

      it 'enables repository' do
        expect { command }.to output(expected_output).to_stdout
        expect(repository.mirroring_enabled).to be_truthy
      end

      it 'enables repository_2' do
        expect { command }.to output(expected_output).to_stdout
        repository_2.reload
        expect(repository_2.mirroring_enabled).to be_truthy
      end

      it 'enables repository_3' do
        expect { command }.to output(expected_output).to_stdout
        repository_3.reload
        expect(repository_3.mirroring_enabled).to be_truthy
      end
    end

    context 'without parameters' do
      let(:argv) { ['enable'] }

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output(/No repository IDs supplied/).to_stderr
      end

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'repo id does not exist' do
      let(:argv) { ['enable', 0] }

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output("Repository by ID 0 not found.\nRepository by ID 0 could not be found and was not enabled.\n").to_stderr
                                  .and output('').to_stdout
      end

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'by repo id' do
      let(:argv) { ['enable', repository.friendly_id] }

      before { expect { command }.to output("Repository by ID #{repository.friendly_id} successfully enabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(true) }
    end
  end

  describe '#disable' do
    subject(:repository) { create :repository, :with_products, mirroring_enabled: true }

    let(:command) do
      repository
      described_class.start(argv)
      repository.reload
    end

    context 'with multiple ids' do
      let(:repository_2) { create :repository, :with_products, mirroring_enabled: true  }
      let(:repository_3) { create :repository, :with_products, mirroring_enabled: true  }
      let(:argv) { ['disable', repository.friendly_id, repository_2.friendly_id, repository_3.friendly_id] }
      let(:expected_output) do
        <<-OUTPUT
Repository by ID #{repository.friendly_id} successfully disabled.
Repository by ID #{repository_2.friendly_id} successfully disabled.
Repository by ID #{repository_3.friendly_id} successfully disabled.

\e[1mTo clean up downloaded files, please run 'rmt-cli repos clean'\e[22m
        OUTPUT
      end

      it 'disables repository' do
        expect { command }.to output(expected_output).to_stdout
        expect(repository.mirroring_enabled).to be_falsey
      end

      it 'disables repository_2' do
        expect { command }.to output(expected_output).to_stdout
        repository_2.reload
        expect(repository_2.mirroring_enabled).to be_falsey
      end

      it 'disables repository_3' do
        expect { command }.to output(expected_output).to_stdout
        repository_3.reload
        expect(repository_3.mirroring_enabled).to be_falsey
      end
    end

    context 'without parameters' do
      let(:argv) { ['disable'] }

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output(/No repository IDs supplied/).to_stderr
      end

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'repo id does not exist' do
      let(:argv) { ['disable', 0] }
      let(:error_message) do
        "Repository by ID 0 not found.\nRepository by ID 0 could not be found and was not disabled.\n"
      end

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output(error_message).to_stderr.and output('').to_stdout
      end

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'by repo id' do
      let(:argv) { ['disable', repository.friendly_id] }
      let(:expected_output) do
        <<-OUTPUT
Repository by ID #{repository.friendly_id} successfully disabled.

\e[1mTo clean up downloaded files, please run 'rmt-cli repos clean'\e[22m
        OUTPUT
      end

      before { expect { command }.to output(expected_output).to_stdout }

      its(:mirroring_enabled) { is_expected.to be(false) }
    end
  end

  describe '#list' do
    shared_context 'rmt-cli repos list' do |command_name|
      subject(:command) { described_class.start(argv) }

      context 'without enabled repositories' do
        let(:argv) { [command_name] }

        it 'outputs success message' do
          expect { command }.to output(
            "Only enabled repositories are shown by default. Use the '--all' option to see all repositories.\n"
          ).to_stdout.and output("No repositories enabled.\n").to_stderr
        end

        context 'with --all option' do
          let(:argv) { [command_name, '--all'] }

          it 'warns about running sync command first' do
            expect { described_class.start(argv) }.to output("Run 'rmt-cli sync' to synchronize with your SUSE Customer Center data first.\n").to_stderr
          end
        end
      end

      context 'with enabled repositories' do
        let!(:repository_one) { FactoryBot.create :repository, :with_products, mirroring_enabled: true }
        let!(:repository_two) { FactoryBot.create :repository, :with_products, mirroring_enabled: false }
        let(:rows) do
          [[
            repository_one.friendly_id,
            repository_one.description,
            repository_one.enabled ? 'Mandatory' : 'Not Mandatory',
            repository_one.mirroring_enabled ? 'Mirror' : "Don't Mirror",
            repository_one.last_mirrored_at
          ]]
        end

        context 'without parameters' do
          let(:argv) { [command_name] }
          let(:expected_output) do
            Terminal::Table.new(
              headings: ['ID', 'Product', 'Mandatory?', 'Mirror?', 'Last mirrored'],
              rows: rows
            ).to_s + "\n" + 'Only enabled repositories are shown by default. Use the \'--all\' option to see all repositories.' + "\n"
          end

          it 'outputs success message' do
            expect { command }.to output(expected_output).to_stdout
          end
        end

        describe "#{command_name} --csv" do
          let(:rows) do
            [[
              repository_one.friendly_id,
              repository_one.name,
              repository_one.description,
              repository_one.enabled,
              repository_one.mirroring_enabled,
              repository_one.last_mirrored_at
            ]]
          end
          let(:argv) { [command_name, '--csv'] }
          let(:expected_output) do
            CSV.generate { |csv| rows.unshift(['ID', 'Product', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored']).each { |row| csv << row } }
          end

          it 'outputs only the expected format' do
            expect { command }.to output(expected_output).to_stdout
          end

          it 'does not output extra information' do
            expect { command }.not_to output(/Use the '--all' option to see all repositories/).to_stdout
          end
        end

        describe "#{command_name} --all" do
          let(:argv) { [command_name, '--all'] }
          let(:expected_output) do
            rows = []
            rows << [
              repository_one.friendly_id,
              repository_one.description,
              repository_one.enabled ? 'Mandatory' : 'Not Mandatory',
              repository_one.mirroring_enabled ? 'Mirror' : "Don't Mirror",
              repository_one.last_mirrored_at
            ]
            rows << [
              repository_two.friendly_id,
              repository_two.description,
              repository_two.enabled ? 'Mandatory' : 'Not Mandatory',
              repository_two.mirroring_enabled ? 'Mirror' : "Don't Mirror",
              repository_two.last_mirrored_at
            ]
            Terminal::Table.new(
              headings: ['ID', 'Product', 'Mandatory?', 'Mirror?', 'Last mirrored'],
              rows: rows
            ).to_s + "\n"
          end

          it 'outputs success message' do
            expect { command }.to output(expected_output).to_stdout
          end
        end
      end
    end

    it_behaves_like 'rmt-cli repos list', 'list'
    it_behaves_like 'rmt-cli repos list', 'ls'
  end
end
