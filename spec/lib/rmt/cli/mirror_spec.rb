require 'rails_helper'

RSpec.describe RMT::CLI::Mirror do
  subject(:command) { described_class.start(argv) }

  let(:argv) { [] }

  describe 'mirror' do
    let(:argv) { ['all'] }

    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end

    context 'suma product tree mirror with exception' do
      before do
        create :repository, :with_products, mirroring_enabled: true
      end

      it 'outputs exception message' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror_suma_product_tree).and_raise(RMT::Mirror::Exception, 'black mirror')
        expect_any_instance_of(RMT::Mirror).to receive(:mirror)
        expect_any_instance_of(RMT::Logger).to receive(:warn).with('black mirror')
        command
      end
    end

    context 'without repositories marked for mirroring' do
      before do
        create :repository, :with_products, mirroring_enabled: false
      end

      it 'outputs a warning' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror_suma_product_tree)
        expect_any_instance_of(RMT::Mirror).not_to receive(:mirror)
        expect { command }.to raise_error(SystemExit).and output("There are no repositories marked for mirroring.\n").to_stderr.and output('').to_stdout
      end
    end

    context 'with repositories marked for mirroring' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }

      it 'updates repository mirroring timestamp' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror_suma_product_tree)
        expect_any_instance_of(RMT::Mirror).to receive(:mirror)

        Timecop.freeze(Time.utc(2018)) do
          expect { command }.to change { repository.reload.last_mirrored_at }.to(Time.now.utc)
        end
      end

      context 'with exceptions during mirroring' do
        before { allow_any_instance_of(RMT::Mirror).to receive(:mirror).and_raise(RMT::Mirror::Exception, 'black mirror') }

        it 'outputs exception message' do
          expect_any_instance_of(RMT::Mirror).to receive(:mirror_suma_product_tree)
          expect_any_instance_of(RMT::Logger).to receive(:warn).with('black mirror')
          command
        end
      end
    end

    context 'with repositories changing during mirroring' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let!(:additional_repository) { create :repository, :with_products, mirroring_enabled: false }

      it 'mirrors additional repositories' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror_suma_product_tree)
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).with(
          repository_url: repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        ) do
          # enable mirroring of the additional repository during mirroring
          additional_repository.mirroring_enabled = true
          additional_repository.save!
        end

        expect_any_instance_of(RMT::Mirror).to receive(:mirror).with(
          repository_url: additional_repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        )

        command
      end
    end

    context 'with repositories changing during mirroring and exceptions occur' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let!(:additional_repository) { create :repository, :with_products, mirroring_enabled: false }

      it 'handles exceptions and mirrors additional repositories' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror_suma_product_tree)
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).with(
          repository_url: repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        ) do
          # enable mirroring of the additional repository during mirroring
          additional_repository.mirroring_enabled = true
          additional_repository.save!
          raise(RMT::Mirror::Exception, 'black mirror')
        end

        expect_any_instance_of(RMT::Logger).to receive(:warn).with('black mirror')
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).with(
          repository_url: additional_repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        )

        command
      end
    end
  end

  describe 'mirror repository' do
    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end

    context 'when repository mirroring is enabled' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let(:argv) { ['repository', repository.scc_id] }

      it 'mirrors the repository' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).with(
          repository_url: repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        )

        command
      end
    end

    context 'when an exception is raised during mirroring' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let(:argv) { ['repository', repository.scc_id] }

      it 'handles the exception and outputs a warning' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once).and_raise(RMT::Mirror::Exception, 'Dummy')
        expect_any_instance_of(RMT::Logger).to receive(:warn).at_least(:once).with('Dummy')
        command
      end
    end

    context 'when repository mirroring is disabled' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: false }
      let(:argv) { ['repository', repository.scc_id] }

      it 'raises an error' do
        expect { command }.to raise_error(SystemExit).and \
          output("Mirroring of repository with ID #{repository.scc_id} is not enabled\n").to_stderr.and \
            output('').to_stdout
      end
    end

    context 'when no repository IDs given' do
      let(:argv) { ['repository'] }

      it 'raises an error' do
        expect { command }.to raise_error(SystemExit).and \
          output("No repository IDs supplied\n").to_stderr.and \
            output('').to_stdout
      end
    end

    context 'when repository with given ID is not found' do
      let(:argv) { ['repository', -42] }

      it 'raises an error' do
        expect { command }.to raise_error(SystemExit).and \
          output("Repository with ID -42 not found\n").to_stderr.and \
            output('').to_stdout
      end
    end
  end

  describe 'mirror product' do
    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end

    context 'when given an ID and product has enabled repos' do
      let(:product) { create :product, :with_mirrored_repositories }
      let(:argv) { ['product', product.id] }

      it 'mirrors repos' do
        product.repositories.each do |repo|
          expect_any_instance_of(RMT::Mirror).to receive(:mirror).with(
            repository_url: repo.external_url,
            local_path: anything,
            repo_name: anything,
            auth_token: anything
          )
        end

        command
      end
    end

    context 'when given a triplet and product has enabled repos' do
      let(:product) { create :product, :with_mirrored_repositories }
      let(:argv) { ['product', [product.identifier, product.version, product.arch].join('/')] }

      it 'mirrors repos' do
        product.repositories.each do |repo|
          expect_any_instance_of(RMT::Mirror).to receive(:mirror).with(
            repository_url: repo.external_url,
            local_path: anything,
            repo_name: anything,
            auth_token: anything
          )
        end

        command
      end
    end

    context 'when an exception is raised during mirroring' do
      let(:product) { create :product, :with_mirrored_repositories }
      let(:argv) { ['product', [product.identifier, product.version, product.arch].join('/')] }

      it 'handles the exception and outputs a warning' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once).and_raise(RMT::Mirror::Exception, 'Dummy')
        expect_any_instance_of(RMT::Logger).to receive(:warn).at_least(:once).with('Dummy')
        command
      end
    end

    context 'when product has no mirrored repos' do
      let(:product) { create :product, :with_not_mirrored_repositories }
      let(:argv) { ['product', product.id] }

      it 'raises an error' do
        expect { command }.to raise_error(SystemExit).and \
          output("Product #{product.id} has no repositories enabled\n").to_stderr.and \
            output('').to_stdout
      end
    end

    context 'when no product IDs given' do
      let(:argv) { ['product'] }

      it 'raises an error' do
        expect { command }.to raise_error(SystemExit).and \
          output("No product IDs supplied\n").to_stderr.and \
            output('').to_stdout
      end
    end

    context "when product with given ID doesn't exist" do
      let(:argv) { ['product', 0] }

      it 'raises an error' do
        expect { command }.to raise_error(SystemExit).and \
          output("Product with ID 0 not found\n").to_stderr.and \
            output('').to_stdout
      end
    end

    context "when product with given target doesn't exist" do
      let(:target) { 'dummy/dummy/dummy' }
      let(:argv) { ['product', target] }

      it 'raises an error' do
        expect { command }.to raise_error(SystemExit).and \
          output("Product for target #{target} not found\n").to_stderr.and \
            output('').to_stdout
      end
    end
  end
end
