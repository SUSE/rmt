require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe RMT::CLI::Repos do
  describe '#enable' do
    subject(:repository) { create :repository, :with_products }

    let(:command) do
      repository
      described_class.start(argv)
      repository.reload
    end

    context 'without parameters' do
      let(:argv) { ['enable'] }

      before { expect { command }.to output(/Usage:/).to_stderr }

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'repo id does not exist' do
      let(:argv) { ['enable', 0] }

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output("Repository not found by id \"0\".\n").to_stderr.and output('').to_stdout
      end

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'by repo id' do
      let(:argv) { ['enable', repository.scc_id.to_s] }

      before { expect { command }.to output("Repository successfully enabled.\n").to_stdout }

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

    context 'without parameters' do
      let(:argv) { ['disable'] }

      before { expect { command }.to output(/Usage:/).to_stderr }

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'repo id does not exist' do
      let(:argv) { ['disable', 0] }

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output("Repository not found by id \"0\".\n").to_stderr.and output('').to_stdout
      end

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'by repo id' do
      let(:argv) { ['disable', repository.scc_id.to_s] }

      before { expect { command }.to output("Repository successfully disabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(false) }
    end
  end

  describe '#list' do
    shared_context 'rmt-cli repos list' do |command_name|
      subject(:command) { described_class.start(argv) }

      context 'without enabled repositories' do
        let(:argv) { [command_name] }

        it 'outputs success message' do
          expect { command }.to output("No repositories enabled.\n").to_stderr
        end

        context 'with --all option' do
          let(:argv) { [command_name, '--all'] }

          it 'warns about running sync command first' do
            expect { described_class.start(argv) }.to output("Run \"rmt-cli sync\" to synchronize with your SUSE Customer Center data first.\n").to_stderr
          end
        end
      end

      context 'with enabled repositories' do
        let!(:repository_one) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }
        let!(:repository_two) { FactoryGirl.create :repository, :with_products, mirroring_enabled: false }

        context 'without parameters' do
          let(:argv) { [command_name] }
          let(:expected_output) do
            rows = []
            rows << [
              repository_one.scc_id,
              repository_one.name,
              repository_one.description,
              repository_one.enabled,
              repository_one.mirroring_enabled,
              repository_one.last_mirrored_at
            ]
            Terminal::Table.new(
              headings: ['SCC ID', 'Name', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored'],
              rows: rows
            ).to_s + "\n" + 'Only enabled repositories are shown by default. Use the `--all` option to see all repositories.' + "\n"
          end

          it 'outputs success message' do
            expect { command }.to output(expected_output).to_stdout
          end
        end

        describe "#{command_name} --all" do
          let(:argv) { [command_name, '--all'] }
          let(:expected_output) do
            rows = []
            rows << [
              repository_one.scc_id,
              repository_one.name,
              repository_one.description,
              repository_one.enabled,
              repository_one.mirroring_enabled,
              repository_one.last_mirrored_at
            ]
            rows << [
              repository_two.scc_id,
              repository_two.name,
              repository_two.description,
              repository_two.enabled,
              repository_two.mirroring_enabled,
              repository_two.last_mirrored_at
            ]
            Terminal::Table.new(
              headings: ['SCC ID', 'Name', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored'],
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
