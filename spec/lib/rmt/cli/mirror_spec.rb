require 'rails_helper'

RSpec.describe RMT::CLI::Mirror do
  subject(:command) { described_class.start(argv) }

  let(:argv) { [] }

  let(:exit_with_error_message) { "The command exited with errors.\n" }
  let(:error_log_begin) { /\e\[31mThe following errors occurred while mirroring:\e\[0m/ }
  let(:error_log_end) { /\e\[33mMirroring completed with errors.\e\[0m/ }
  let(:error_log) { /.*#{error_log_begin}\n.*\e\[31m#{error_messages}\e\[0m\n.*#{error_log_end}/ }

  describe 'mirror' do
    let(:argv) { ['all'] }

    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end

    context 'suma product tree mirror with exception' do
      before do
        create :repository, :with_products, mirroring_enabled: true
      end

      let(:suma_error) { 'mirroring SUMA failed' }
      let(:error_messages) { "Mirroring SUMA product tree failed: #{suma_error}." }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'handles the exception and raises an error after mirroring all repos' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
        allow(rmt_mirror)
          .to receive(:mirror_suma_product_tree)
          .and_raise(RMT::Mirror::Exception, suma_error)
        allow(rmt_mirror).to receive(:mirror)

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end

    context 'without repositories marked for mirroring' do
      before do
        create :repository, :with_products, mirroring_enabled: false
      end

      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'raises an error' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
        allow(rmt_mirror).to receive(:mirror_suma_product_tree)

        expect { command }
          .to raise_error(SystemExit)
          .and output("There are no repositories marked for mirroring.\n").to_stderr
          .and output('').to_stdout
      end
    end

    context 'with repositories marked for mirroring' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'updates repository mirroring timestamp' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
        allow(rmt_mirror).to receive(:mirror_suma_product_tree)
        allow(rmt_mirror).to receive(:mirror)

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
          allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)

          allow(rmt_mirror)
          .to receive(:mirror)
          .and_raise(RMT::Mirror::Exception, mirroring_error)
          allow(rmt_mirror).to receive(:mirror_suma_product_tree)

          expect { command }
            .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
            .and output(error_log).to_stdout
            .and output(exit_with_error_message).to_stderr
        end
      end
    end

    context 'with repositories in alpha or beta stage' do
      let(:product) { create :beta }
      let(:mirrored) { create(:product, :module, :with_mirrored_repositories, base_products: [product], root_product: product, recommended: true) }
      let(:repos) { mirrored.repositories }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      let(:mirroring_error) { 'mirroring failed' }
      let(:error_log) { /.*#{error_log_begin}\n#{error_messages}#{error_log_end}/ }
      let(:error_messages) do
        full_message = Regexp.new ''
        repos.each do |repo|
          repo_error = /.*\e\[31mRepository '#{repo.name}' \(#{repo.friendly_id}\): #{mirroring_error}\.\e\[0m\n.*/
          full_message = Regexp.new(full_message.source + repo_error.source)
        end
        full_message
      end

      context 'using --do-not-raise-unpublished flag' do
        let(:argv) { ['all', '--do-not-raise-unpublished'] }

        it 'log the warning and does not raise an error' do
          allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
          allow(rmt_mirror)
            .to receive(:mirror)
            .and_raise(RMT::Mirror::Exception, mirroring_error)

          allow(rmt_mirror).to receive(:mirror_suma_product_tree)
          expect { command }.to output(error_log).to_stdout
        end
      end
    end

    context 'with repositories changing during mirroring' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let!(:additional_repository) { create :repository, :with_products, mirroring_enabled: false }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'mirrors additional repositories' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
        allow(rmt_mirror).to receive(:mirror_suma_product_tree)
        allow(rmt_mirror).to receive(:mirror).with(
          repository_url: repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        ) do
          # enable mirroring of the additional repository during mirroring
          additional_repository.mirroring_enabled = true
          additional_repository.save!
        end.and_return([1, 32323])

        allow(rmt_mirror).to receive(:mirror).with(
          repository_url: additional_repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        ).and_return([1, 32323])

        $stdout = StringIO.new

        command

        $stdout.rewind

        expect($stdout.gets).to match(/Total mirrored repositories: 2/)
        expect($stdout.gets).to match(/Total transferred files: 2/)
        expect($stdout.gets).to match(/Total transferred file size: 63.1 KB/)
        expect($stdout.gets).to match(/Total Mirror Time: 00:00:00/)
        expect($stdout.gets).to match(/Mirroring complete./)
      end
    end

    context 'with repositories changing during mirroring and exceptions occur' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let!(:additional_repository) { create :repository, :with_products, mirroring_enabled: false }
      let(:mirroring_error) { 'mirroring failed' }
      let(:error_messages) { /Repository '#{repository.name}' \(#{repository.friendly_id}\): #{mirroring_error}\./ }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'handles exceptions and mirrors additional repositories' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
        allow(rmt_mirror).to receive(:mirror_suma_product_tree)
        allow(rmt_mirror).to receive(:mirror).with(
          repository_url: repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        ) do
          # enable mirroring of the additional repository during mirroring
          additional_repository.mirroring_enabled = true
          additional_repository.save!
          raise(RMT::Mirror::Exception, mirroring_error)
        end

        allow(rmt_mirror).to receive(:mirror).with(
          repository_url: additional_repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        )

        expect { command }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and output(error_log).to_stdout
          .and output(exit_with_error_message).to_stderr
      end
    end
  end

  describe 'mirror repository' do
    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end

    context 'when repository mirroring is enabled' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let(:argv) { ['repository', repository.friendly_id] }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'mirrors the repository' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
        allow(rmt_mirror).to receive(:mirror).with(
          repository_url: repository.external_url,
          local_path: anything,
          repo_name: anything,
          auth_token: anything
        ).and_return([1, 8765])

        $stdout = StringIO.new

        command

        $stdout.rewind

        expect($stdout.gets).to match(/Total mirrored repositories: 1/)
        expect($stdout.gets).to match(/Total transferred files: 1/)
        expect($stdout.gets).to match(/Total transferred file size: 8.56 KB/)
        expect($stdout.gets).to match(/Total Mirror Time: 00:00:00/)
        expect($stdout.gets).to match(/Mirroring complete./)
      end
    end

    context 'when an exception is raised during mirroring' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }
      let(:argv) { ['repository', repository.friendly_id] }
      let(:mirroring_error) { 'mirroring failed' }
      let(:error_messages) { /Repository '#{repository.name}' \(#{repository.friendly_id}\): #{mirroring_error}\./ }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'handles the exception and raises an error after mirroring all repos' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
        allow(rmt_mirror)
          .to receive(:mirror).at_least(:once)
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
    context 'lockfiles', :with_fakefs do
      include_examples 'handles lockfile exception'
    end

    context 'when given an ID and product has enabled repos' do
      let(:product) { create :product, :with_mirrored_repositories }
      let(:argv) { ['product', product.id] }
      let(:repos_count) { product.repositories.count }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'mirrors repos' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)

        product.repositories.each do |repo|
          allow(rmt_mirror).to receive(:mirror).with(
            repository_url: repo.external_url,
            local_path: anything,
            repo_name: anything,
            auth_token: anything
          ).and_return([repos_count, 89987332.33])
        end

        $stdout = StringIO.new

        command

        $stdout.rewind

        expect($stdout.gets).to match(/Total mirrored repositories: #{repos_count}/)
        expect($stdout.gets).to match(/Total transferred files: 16/)
        expect($stdout.gets).to match(/Total transferred file size: 343 MB/)
        expect($stdout.gets).to match(/Total Mirror Time: 00:00:00/)
        expect($stdout.gets).to match(/Mirroring complete./)
      end
    end

    context 'when given a triplet and product has enabled repos' do
      let(:product) { create :product, :with_mirrored_repositories }
      let(:argv) { ['product', [product.identifier, product.version, product.arch].join('/')] }
      let(:repos_count) { product.repositories.count }
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'mirrors repos' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)

        product.repositories.each do |repo|
          allow(rmt_mirror).to receive(:mirror).with(
            repository_url: repo.external_url,
            local_path: anything,
            repo_name: anything,
            auth_token: anything
          ).and_return([repos_count, 89987332.33])
        end

        $stdout = StringIO.new

        command

        $stdout.rewind

        expect($stdout.gets).to match(/Total mirrored repositories: #{repos_count}/)
        expect($stdout.gets).to match(/Total transferred files: 16/)
        expect($stdout.gets).to match(/Total transferred file size: 343 MB/)
        expect($stdout.gets).to match(/Total Mirror Time: 00:00:00/)
        expect($stdout.gets).to match(/Mirroring complete./)
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
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      it 'handles the exception and raises an error after mirroring all repos' do
        allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
        allow(rmt_mirror)
          .to receive(:mirror).at_least(:once)
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
      let(:rmt_mirror) { instance_double(RMT::Mirror) }

      context 'mirror product using --do-not-raise-unpublished flag' do
        it 'log the warning and does not raise an error' do
          allow(RMT::Mirror).to receive(:new).and_return(rmt_mirror)
          allow(rmt_mirror).to receive(:mirror_suma_product_tree)
          expect { command }.to output(error_log).to_stdout
        end
      end
    end
  end
end
