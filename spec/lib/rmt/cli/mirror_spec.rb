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
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let(:error_message) { 'mirroring SUMA failed' }

      it 'handles the exception and raises an error after mirroring all repos' do
        expect_any_instance_of(RMT::Mirror)
          .to receive(:mirror_suma_product_tree)
          .and_raise(RMT::Mirror::Exception, error_message)
        expect_any_instance_of(RMT::Mirror).to receive(:mirror)

        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          Mirroring SUMA product tree failed: #{error_message}
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message).to_stderr
          .and output('').to_stdout
      end

      context 'with repository exceptions during mirroring' do
        it 'handles the exception and raises an error after mirroring all repos' do
          expect_any_instance_of(RMT::Mirror)
            .to receive(:mirror_suma_product_tree)
            .and_raise(RMT::Mirror::Exception, error_message)
          expect_any_instance_of(RMT::Mirror)
            .to receive(:mirror).at_least(:once)
            .and_raise(RMT::Mirror::Exception, error_message)

          expected_message = <<~MSG
            The following errors ocurred while mirroring:
            Mirroring SUMA product tree failed: #{error_message}
            Repository '#{repository.name}' (#{repository.id}): #{error_message}
          MSG

          expect { command }
            .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
            .and output(expected_message).to_stderr
            .and output('').to_stdout
        end
      end
    end

    context 'without repositories marked for mirroring' do
      before do
        create :repository, :with_products, mirroring_enabled: false
      end

      it 'raises an error' do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror_suma_product_tree)
        expect_any_instance_of(RMT::Mirror).not_to receive(:mirror)

        expect { command }
          .to raise_error(SystemExit)
          .and output("There are no repositories marked for mirroring.\n").to_stderr
          .and output('').to_stdout
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
        before do
          allow_any_instance_of(RMT::Mirror)
            .to receive(:mirror)
            .and_raise(RMT::Mirror::Exception, error_message)
        end

        let(:error_message) { 'mirroring failed' }

        it 'raises an error' do
          expect_any_instance_of(RMT::Mirror).to receive(:mirror_suma_product_tree)

          expected_message = <<~MSG
            The following errors ocurred while mirroring:
            Repository '#{repository.name}' (#{repository.id}): #{error_message}
          MSG

          expect { command }
            .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
            .and output(expected_message).to_stderr
            .and output('').to_stdout
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
      let(:error_message) { 'mirroring failed' }

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
          raise(RMT::Mirror::Exception, error_message)
        end

        expect_any_instance_of(RMT::Mirror).to receive(:mirror).with(
          repository_url: additional_repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        )

        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          Repository '#{repository.name}' (#{repository.id}): #{error_message}
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message).to_stderr
          .and output('').to_stdout
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
      let(:error_message) { 'mirroring failed' }

      it 'handles the exception and raises an error after mirroring all repos' do
        expect_any_instance_of(RMT::Mirror)
          .to receive(:mirror).at_least(:once)
          .and_raise(RMT::Mirror::Exception, error_message)

        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          Repository '#{repository.name}' (#{repository.id}): #{error_message}
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message).to_stderr
          .and output('').to_stdout
      end
    end

    context 'when repository mirroring is disabled' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: false }
      let(:argv) { ['repository', repository.scc_id] }

      it 'raises an error' do
        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          Mirroring of repository with ID #{repository.scc_id} is not enabled
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message).to_stderr
          .and output('').to_stdout
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
        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          Repository with ID -42 not found
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message)
          .to_stderr.and output('').to_stdout
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
      let(:error_message) { 'mirroring failed' }

      it 'handles the exception and raises an error after mirroring all repos' do
        expect_any_instance_of(RMT::Mirror)
          .to receive(:mirror).at_least(:once)
          .and_raise(RMT::Mirror::Exception, error_message)

        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          #{product.repositories.map { |r| "Repository '#{r.name}' (#{r.id}): #{error_message}" }.join("\n")}
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message).to_stderr
          .and output('').to_stdout
      end
    end

    context 'when product has no mirrored repos' do
      let(:product) { create :product, :with_not_mirrored_repositories }
      let(:argv) { ['product', product.id] }

      it 'raises an error' do
        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          Product #{product.id} has no repositories enabled
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message)
          .to_stderr.and output('').to_stdout
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
        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          Product with ID 0 not found
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message)
          .to_stderr.and output('').to_stdout
      end
    end

    context "when product with given target doesn't exist" do
      let(:target) { 'dummy/dummy/dummy' }
      let(:argv) { ['product', target] }

      it 'raises an error' do
        expected_message = <<~MSG
          The following errors ocurred while mirroring:
          Product for target #{target} not found
        MSG

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(expected_message)
          .to_stderr.and output('').to_stdout
      end
    end
  end
end
