require 'rails_helper'

RSpec.describe RMT::CLI::Repos do
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
      let(:argv) { ['enable', repository.scc_id.to_s, repository_2.scc_id.to_s, repository_3.scc_id.to_s] }
      let(:expected_output) do
        <<-OUTPUT
Repository by ID #{repository.scc_id} successfully enabled.
Repository by ID #{repository_2.scc_id} successfully enabled.
Repository by ID #{repository_3.scc_id} successfully enabled.
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
        expect { command }.to output(/No repository ids supplied/).to_stderr
      end

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'repo id does not exist' do
      let(:argv) { ['enable', 0] }

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output("Repository not found by ID 0.\nRepository 0 could not be found and was not enabled.\n").to_stderr
                                  .and output('').to_stdout
      end

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'by repo id' do
      let(:argv) { ['enable', repository.scc_id.to_s] }

      before { expect { command }.to output("Repository by ID #{repository.scc_id} successfully enabled.\n").to_stdout }

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
      let(:argv) { ['disable', repository.scc_id.to_s, repository_2.scc_id.to_s, repository_3.scc_id.to_s] }
      let(:expected_output) do
        <<-OUTPUT
Repository by ID #{repository.scc_id} successfully disabled.
Repository by ID #{repository_2.scc_id} successfully disabled.
Repository by ID #{repository_3.scc_id} successfully disabled.
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
        expect { command }.to output(/No repository ids supplied/).to_stderr
      end

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'repo id does not exist' do
      let(:argv) { ['disable', 0] }
      let(:error_message) do
        "Repository not found by ID 0.\nRepository 0 could not be found and was not disabled.\n"
      end

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output(error_message).to_stderr.and output('').to_stdout
      end

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'by repo id' do
      let(:argv) { ['disable', repository.scc_id.to_s] }

      before { expect { command }.to output("Repository by ID #{repository.scc_id} successfully disabled.\n").to_stdout }

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
        let!(:repository_one) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }
        let!(:repository_two) { FactoryGirl.create :repository, :with_products, mirroring_enabled: false }
        let(:rows) do
          [[
            repository_one.scc_id,
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
              headings: ['SCC ID', 'Product', 'Mandatory?', 'Mirror?', 'Last mirrored'],
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
              repository_one.scc_id,
              repository_one.name,
              repository_one.description,
              repository_one.enabled,
              repository_one.mirroring_enabled,
              repository_one.last_mirrored_at
            ]]
          end
          let(:argv) { [command_name, '--csv'] }
          let(:expected_output) do
            CSV.generate { |csv| rows.unshift(['SCC ID', 'Product', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored']).each { |row| csv << row } }
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
              repository_one.scc_id,
              repository_one.description,
              repository_one.enabled ? 'Mandatory' : 'Not Mandatory',
              repository_one.mirroring_enabled ? 'Mirror' : "Don't Mirror",
              repository_one.last_mirrored_at
            ]
            rows << [
              repository_two.scc_id,
              repository_two.description,
              repository_two.enabled ? 'Mandatory' : 'Not Mandatory',
              repository_two.mirroring_enabled ? 'Mirror' : "Don't Mirror",
              repository_two.last_mirrored_at
            ]
            Terminal::Table.new(
              headings: ['SCC ID', 'Product', 'Mandatory?', 'Mirror?', 'Last mirrored'],
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
