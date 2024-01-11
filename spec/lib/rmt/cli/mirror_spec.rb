require 'rails_helper'

RSpec.describe RMT::CLI::Mirror do
  subject(:command) { described_class.start(argv) }

  let(:argv) { [] }

  let!(:repository) { create :repository, :with_products, mirroring_enabled: default_repository_enabled }
  let(:default_repository_enabled) { true }

  let(:exit_with_error_message) { "The command exited with errors.\n" }
  let(:error_log_begin) { /\e\[31mThe following errors occurred while mirroring:\e\[0m/ }
  let(:error_log_end) { /\e\[33mMirroring completed with errors.\e\[0m/ }
  let(:error_log) { /.*#{error_log_begin}\n.*\e\[31m#{error_messages}\e\[0m\n.*#{error_log_end}/ }

  describe '#all' do
    let(:argv) { ['all'] }

    let(:suma) { instance_double(RMT::Mirror::SumaProductTree) }

    before do
      allow(RMT::Mirror::SumaProductTree).to receive(:new).and_return(suma)
      allow(suma).to receive(:mirror)
      allow_any_instance_of(RMT::Mirror).to receive(:mirror_now)
    end

    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end


    context 'suma product tree mirror with exception' do
      let(:suma_error) { 'mirroring SUMA failed' }
      let(:error_messages) { "Mirroring SUMA product tree failed: #{suma_error}." }

      it 'handles the exception and raises an error after mirroring all repos' do
        allow(suma).to receive(:mirror).and_raise(RMT::Mirror::Exception, suma_error)

        expect { command }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end

    context 'without repositories marked for mirroring' do
      let(:default_repository_enabled) { false }

      it 'raises an error' do
        expect { command }.to raise_error(SystemExit)
          .and output("There are no repositories marked for mirroring.\n").to_stderr
          .and output('').to_stdout
      end
    end

    context 'with repositories marked for mirroring' do
      it 'updates repository mirroring timestamp' do
        Timecop.freeze(Time.utc(2018)) do
          expect { command }
            .to change { repository.reload.last_mirrored_at }.to(Time.now.utc)
            .and output(/\e\[32mMirroring complete.\e\[0m/).to_stdout
        end
      end

      context 'with exceptions during mirroring' do
        let(:mirroring_error) { 'mirroring failed' }
        let(:error_messages) { /Repository '#{repository.name}' \(#{repository.friendly_id}\): #{mirroring_error}\./ }

        it 'raises an error' do
          allow_any_instance_of(RMT::Mirror).to receive(:mirror_now)
            .and_raise(RMT::Mirror::Exception, mirroring_error)

          expect { command }
            .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
            .and output(error_log).to_stdout
            .and output(exit_with_error_message).to_stderr
        end
      end
    end

    context 'with repositories in alpha or beta stage' do
      let(:argv) { ['all', '--do-not-raise-unpublished'] }
      let(:default_repository_enabled) { false }

      let(:product) { create :beta }
      let(:mirrored) { create(:product, :module, :with_mirrored_repositories, base_products: [product], root_product: product, recommended: true) }
      let(:repositories) { mirrored.repositories }

      let(:mirroring_error) { 'mirroring failed' }
      let(:error_log) { /.*#{error_log_begin}\n#{error_messages}#{error_log_end}/ }
      let(:error_messages) do
        full_message = Regexp.new ''
        repositories.each do |repo|
          repo_error = /.*\e\[31mRepository '#{repo.name}' \(#{repo.friendly_id}\): #{mirroring_error}\.\e\[0m\n.*/
          full_message = Regexp.new(full_message.source + repo_error.source)
        end
        full_message
      end

      context 'using --do-not-raise-unpublished flag' do
        it 'log the warning and does not raise an error' do
          allow_any_instance_of(RMT::Mirror)
            .to receive(:mirror_now)
            .and_raise(RMT::Mirror::Exception, mirroring_error)

          expect { command }.to output(error_log).to_stdout
        end
      end
    end

    context 'with repositories changing during mirroring' do
      let!(:additional_repository) { create :repository, :with_products, mirroring_enabled: false }

      it 'mirrors additional repositories' do
        expect_any_instance_of(described_class).to receive(:mirror_repositories!).with([repository]) do
          # enable mirroring of the additional repository during mirroring
          additional_repository.update!(mirroring_enabled: true)
        end
        expect_any_instance_of(described_class).to receive(:mirror_repositories!).with([additional_repository])
        expect { command }.to output(/\e\[32mMirroring complete.\e\[0m/).to_stdout
      end

      context 'failed repository mirroring' do
        let(:argv) { ['all', '--do-not-raise-unpublished'] }

        let(:mirroring_error) { 'mirroring failed' }
        let(:error_messages) { /Repository '#{repository.name}' \(#{repository.friendly_id}\): #{mirroring_error}\./ }

        let(:mirror_repo) { instance_double(RMT::Mirror) }
        let(:mirror_add_repo) { instance_double(RMT::Mirror) }

        before do
          allow(RMT::Mirror).to receive(:new).with(
            repository: repository,
            logger: anything,
            mirroring_base_dir: anything,
            mirror_sources: anything,
            is_airgapped: anything
          ).and_return(mirror_repo)

          allow(RMT::Mirror).to receive(:new).with(
            repository: additional_repository,
            logger: anything,
            mirroring_base_dir: anything,
            mirror_sources: anything,
            is_airgapped: anything
          ).and_return(mirror_add_repo)
        end

        it 'handles exceptions and mirrors additional repositories' do
          expect(mirror_repo).to receive(:mirror_now) do
            # enable mirroring of the additional repository during mirroring
            additional_repository.update!(mirroring_enabled: true)
          end.and_raise(RMT::Mirror::Exception, mirroring_error)

          expect(mirror_add_repo).to receive(:mirror_now)

          expect { command }
            .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
            .and output(error_log).to_stdout
            .and output(exit_with_error_message).to_stderr
        end
      end
    end
  end

  describe 'mirror repository' do
    before do
      allow(RMT::Mirror::SumaProductTree).to receive(:new)
      allow_any_instance_of(RMT::Mirror).to receive(:mirror_now)
    end

    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end


    context 'when repository mirroring is enabled' do
      let(:argv) { ['repository', repository.friendly_id] }

      it 'mirrors the repository' do
        expect { command }.to output(/\e\[32mMirroring complete.\e\[0m/).to_stdout
      end
    end

    context 'when an exception is raised during mirroring' do
      let(:argv) { ['repository', repository.friendly_id] }
      let(:mirroring_error) { 'mirroring failed' }
      let(:error_messages) { /Repository '#{repository.name}' \(#{repository.friendly_id}\): #{mirroring_error}\./ }

      it 'handles the exception and raises an error after mirroring all repos' do
        allow_any_instance_of(RMT::Mirror)
          .to receive(:mirror_now)
          .and_raise(RMT::Mirror::Exception, mirroring_error)

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end

    context 'when repository mirroring is disabled' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: false }
      let(:argv) { ['repository', repository.friendly_id] }
      let(:error_messages) { "Mirroring of repository with ID #{repository.friendly_id} is not enabled." }

      it 'raises an error' do
        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end

    context 'when no repository IDs given' do
      let(:argv) { ['repository'] }

      it 'raises an error' do
        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output("No repository IDs supplied\n")
          .to_stderr.and output('').to_stdout
      end
    end

    context 'when repository with given ID is not found' do
      let(:argv) { ['repository', -42] }
      let(:error_messages) { 'Repository with ID -42 not found.' }

      it 'raises an error' do
        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end
  end

  describe 'mirror product' do
    before do
      allow(RMT::Mirror::SumaProductTree).to receive(:new)
      allow_any_instance_of(RMT::Mirror).to receive(:mirror_now)
    end

    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end


    context 'when given an ID and product has enabled repos' do
      let(:product) { create :product, :with_mirrored_repositories }
      let(:argv) { ['product', product.id] }

      it 'mirrors repos' do
        expect_any_instance_of(described_class).to receive(:mirror_repositories!).with(product.repositories)

        expect { command }.to output(/\e\[32mMirroring complete.\e\[0m/).to_stdout
      end
    end

    context 'when given a triplet and product has enabled repos' do
      let(:product) { create :product, :with_mirrored_repositories }
      let(:argv) { ['product', [product.identifier, product.version, product.arch].join('/')] }

      it 'mirrors repos' do
        expect_any_instance_of(described_class).to receive(:mirror_repositories!).with(product.repositories)

        expect { command }.to output(/\e\[32mMirroring complete.\e\[0m/).to_stdout
      end
    end

    context 'when an exception is raised during mirroring' do
      let(:product) { create :product, :with_mirrored_repositories }
      let(:argv) { ['product', [product.identifier, product.version, product.arch].join('/')] }
      let(:mirroring_error) { 'mirroring failed' }
      let(:error_messages) do
        product.repositories
          .map { |repo| /Repository '#{repo.name}' \(#{repo.friendly_id}\): #{mirroring_error}\./ }
          .reduce { |acc, e| /#{acc}\e\[0m\n.*\e\[31m#{e}/ }
      end

      it 'handles the exception and raises an error after mirroring all repos' do
        allow_any_instance_of(RMT::Mirror)
          .to receive(:mirror_now)
          .and_raise(RMT::Mirror::Exception, mirroring_error)

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end

    context 'when product has no mirrored repos' do
      let(:product) { create :product, :with_not_mirrored_repositories }
      let(:argv) { ['product', product.id] }
      let(:error_messages) { "Product #{product.id} has no repositories enabled." }

      it 'raises an error' do
        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end

    context 'when no product IDs given' do
      let(:argv) { ['product'] }

      it 'raises an error' do
        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output("No product IDs supplied\n")
          .to_stderr.and output('').to_stdout
      end
    end

    context "when product with given ID doesn't exist" do
      let(:argv) { ['product', 0] }
      let(:error_messages) { 'Product with ID 0 not found.' }

      it 'raises an error' do
        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end

    context "when product with given target doesn't exist" do
      let(:target) { 'dummy/dummy/dummy' }
      let(:argv) { ['product', target] }
      let(:error_messages) { "Product for target #{target} not found." }

      it 'raises an error' do
        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end

    context 'with repositories in alpha or beta stage' do
      let(:product) { create(:beta) }
      let(:mirroring_error) { 'has no repositories enabled' }
      let(:error_log) { /.*#{error_log_begin}\n#{error_messages}#{error_log_end}/ }
      let(:error_messages) { /.*\e\[31mProduct #{product.id} #{mirroring_error}\.\e\[0m\n.*/ }
      let(:argv) { ['product', product.id, '--do-not-raise-unpublished'] }

      context 'mirror product using --do-not-raise-unpublished flag' do
        it 'log the warning and does not raise an error' do
          allow_any_instance_of(RMT::Mirror::SumaProductTree).to receive(:mirror)
          expect { command }.to output(error_log).to_stdout
        end
      end
    end
  end
end
