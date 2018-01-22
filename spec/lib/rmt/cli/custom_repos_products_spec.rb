require 'rails_helper'

# rubocop:disable RSpec/MultipleExpectations

describe RMT::CLI::CustomReposProducts do
  subject(:command) { described_class.start(argv) }

  let(:product) { create :product }
  let(:repository_service) { RepositoryService.new }

  describe '#add' do
    context 'repository does not exist' do
      let(:argv) { ['add', 'foo', product.id] }

      it 'fails' do
        expect { described_class.start(argv) }.to output("Cannot find custom repository by id \"foo\".\n").to_stderr.and output('').to_stdout
      end
    end

    context 'repository is from scc' do
      let(:repository) { create :repository }
      let(:argv) { ['add', repository.id, product.id] }

      it('does not have an attached product') { expect(repository.products.count).to eq(0) }

      it 'fails' do
        expect { described_class.start(argv) }.to output("Cannot find custom repository by id \"#{repository.id}\".\n").to_stderr.and output('').to_stdout
        expect(repository.products.count).to eq(0)
      end
    end

    context 'product does not exist' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['add', repository.id, 'foo'] }

      it('does not have an attached product') { expect(repository.products.count).to eq(0) }

      it 'fails' do
        expect { described_class.start(argv) }.to output("Cannot find product by id \"foo\".\n").to_stderr.and output('').to_stdout
        expect(repository.products.count).to eq(0)
      end
    end

    context 'product and repo exist' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['add', repository.id, product.id] }

      it('does not have an attached product') { expect(repository.products.count).to eq(0) }

      it 'adds the repository to the database' do
        expect { described_class.start(argv) }.to output('').to_stderr.and output("Added repository to product\n").to_stdout
        expect(repository.products.first.id).to eq(product.id)
      end
    end
  end

  describe '#remove' do
    shared_context 'rmt-cli custom repos products remove' do |command|
      context 'repository does not exist' do
        let(:argv) { [command, 'foo', product.id] }

        it 'fails' do
          expect { described_class.start(argv) }.to output("Cannot find custom repository by id \"foo\".\n").to_stderr.and output('').to_stdout
        end
      end

      context 'repository is from scc' do
        let(:repository) { create :repository }
        let(:argv) { [command, 'foo', repository.id] }

        before do
          repository_service.add_product(product, repository)
        end

        it('has an attached product') { expect(repository.products.count).to eq(1) }

        it 'fails' do
          expect { described_class.start(argv) }.to output("Cannot find custom repository by id \"foo\".\n").to_stderr.and output('').to_stdout
          expect(repository.products.count).to eq(1)
        end
      end

      context 'product does not exist' do
        let(:repository) { create :repository, :custom }
        let(:argv) { [command, repository.id, 'foo'] }

        before do
          repository_service.add_product(product, repository)
        end

        it('has an attached product') { expect(repository.products.count).to eq(1) }

        it 'fails' do
          expect { described_class.start(argv) }.to output("Cannot find product by id \"foo\".\n").to_stderr.and output('').to_stdout
          expect(repository.products.count).to eq(1)
        end
      end

      context 'product and repo exist' do
        let(:repository) { create :repository, :custom }
        let(:argv) { [command, repository.id, product.id] }

        before do
          repository_service.add_product(product, repository)
        end

        it('has an attached product') { expect(repository.products.count).to eq(1) }

        it 'adds the repository to the database' do
          expect { described_class.start(argv) }.to output('').to_stderr.and output("Removed repository from product\n").to_stdout
          expect(repository.products.count).to eq(0)
        end
      end
    end

    it_behaves_like 'rmt-cli custom repos products remove', 'remove'
    it_behaves_like 'rmt-cli custom repos products remove', 'rm'
  end

  describe '#list' do
    shared_context 'rmt-cli custom repos products list' do |command|
      context 'scc repository' do
        let(:repository) { create :repository }
        let(:argv) { [command, repository.id] }

        before do
          repository_service.add_product(product, repository)
        end

        it('has an attached product') { expect(repository.products.count).to eq(1) }

        it 'does not displays the product' do
          expect { described_class.start(argv) }.to output("Cannot find custom repository by id \"#{repository.id}\".\n").to_stderr.and output('').to_stdout
        end
      end

      context 'custom repository with products' do
        let(:repository) { create :repository, :custom }
        let(:argv) { [command, repository.id] }

        before do
          repository_service.add_product(product, repository)
        end

        it('has an attached product') { expect(repository.products.count).to eq(1) }

        it 'displays the product' do
          expect { described_class.start(argv) }.to output(/.*#{product.name}.*/).to_stdout
        end
      end

      context 'custom repository without products' do
        let(:repository) { create :repository, :custom }
        let(:argv) { [command, repository.id] }

        it('does not have an attached product') { expect(repository.products.count).to eq(0) }

        it 'displays the product' do
          expect { described_class.start(argv) }.to output('').to_stdout.and output("No products attached to repository.\n").to_stderr
        end
      end
    end

    it_behaves_like 'rmt-cli custom repos products list', 'list'
    it_behaves_like 'rmt-cli custom repos products list', 'ls'
  end
end
