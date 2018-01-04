require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe RMT::CLI::Repos do
  before { allow(described_class).to receive(:exit) { raise 'Called exit unexpectedly' } }

  describe '#enable' do
    subject(:repository) { FactoryGirl.create :repository, :with_products }

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

    context 'by repo id' do
      let(:argv) { ['enable', repository.id.to_s] }

      before { expect { command }.to output("Repository successfully enabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'by product without arch' do
      let(:product) { repository.services.first.product }
      let(:argv) { ['enable', "#{product.identifier}/#{product.version}"] }

      before { expect { command }.to output("1 repo(s) successfully enabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'by product with arch' do
      let(:product) { repository.services.first.product }
      let(:argv) { ['enable', "#{product.identifier}/#{product.version}/#{product.arch}"] }

      before { expect { command }.to output("1 repo(s) successfully enabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(true) }
    end
  end

  describe '#disable' do
    subject(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }

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

    context 'by repo id' do
      let(:argv) { ['disable', repository.id.to_s] }

      before { expect { command }.to output("Repository successfully disabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'by product without arch' do
      let(:product) { repository.services.first.product }
      let(:argv) { ['disable', "#{product.identifier}/#{product.version}"] }

      before { expect { command }.to output("1 repo(s) successfully disabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'by product with arch' do
      let(:product) { repository.services.first.product }
      let(:argv) { ['disable', "#{product.identifier}/#{product.version}/#{product.arch}"] }

      before { expect { command }.to output("1 repo(s) successfully disabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(false) }
    end
  end

  %w[list ls].each do |command_name|
    describe "##{command_name}" do
      subject(:command) { described_class.start(argv) }

      context 'without enabled repositories' do
        let(:argv) { [command_name] }

        it 'outputs success message' do
          expect { command }.to output("No repositories enabled.\n").to_stderr
        end

        context 'with --all option' do
          let(:argv) { [command_name, '--all'] }

          it 'warns about running sync command first' do
            expect { described_class.start(argv) }.to output(
              "Run \"rmt-cli sync\" to synchronize with your SUSE Customer Center data first.\n"
                                                      ).to_stderr
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
              repository_one.id,
              repository_one.name,
              repository_one.description,
              repository_one.enabled,
              repository_one.mirroring_enabled,
              repository_one.last_mirrored_at
            ]
            Terminal::Table.new(
              headings: ['ID', 'Name', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored'],
              rows: rows
            ).to_s + "\n"
          end

          it 'outputs success message' do
            expect { command }.to output(expected_output).to_stdout
          end
        end

        context 'list all' do
          let(:argv) { [command_name, '--all'] }
          let(:expected_output) do
            rows = []
            rows << [
              repository_one.id,
              repository_one.name,
              repository_one.description,
              repository_one.enabled,
              repository_one.mirroring_enabled,
              repository_one.last_mirrored_at
            ]
            rows << [
              repository_two.id,
              repository_two.name,
              repository_two.description,
              repository_two.enabled,
              repository_two.mirroring_enabled,
              repository_two.last_mirrored_at
            ]
            Terminal::Table.new(
              headings: ['ID', 'Name', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored'],
              rows: rows
            ).to_s + "\n"
          end

          it 'outputs success message' do
            expect { command }.to output(expected_output).to_stdout
          end
        end
      end
    end
  end
end
