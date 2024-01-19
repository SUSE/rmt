require 'rails_helper'

describe RMT::CLI::ReposCustom do
  subject(:command) { described_class.start(argv) }

  let(:product) { create :product, :with_service }
  let(:external_url) { 'http://example.com/repos/' }
  let(:repository_service) { RepositoryService.new }

  describe '#add' do
    let(:argv) { ['add', external_url, 'foo'] }

    it 'adds the repository to the database' do
      expect { described_class.start(argv) }.to output("Successfully added custom repository.\n").to_stdout.and output('').to_stderr
      expect(Repository.find_by(external_url: external_url)).not_to be_nil
    end

    context '--id parameter' do
      subject(:custom_repo) { Repository.find_by(external_url: external_url) }

      let(:argv) { ['add', external_url, 'bar', '--id', 'foo'] }

      before do
        expect { described_class.start(argv) }.to output("Successfully added custom repository.\n").to_stdout.and output('').to_stderr
      end

      it 'sets the name' do
        expect(custom_repo.name).to eq('bar')
      end

      it 'sets the friendly_id' do
        expect(custom_repo.friendly_id).to eq('foo')
      end
    end

    context 'numeric IDs' do
      let(:argv) { ['add', external_url, 'foo', '--id', '123'] }

      it 'adds the repository to the database' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }
            .to output("\e[31mPlease provide a non-numeric ID for your custom repository.\e[0m\nCouldn't add custom repository.\n").to_stderr
            .and output('').to_stdout
        expect(Repository.find_by(external_url: external_url)).to be_nil
      end
    end

    context 'numeric name' do
      let(:argv) { ['add', external_url, '123'] }

      it 'adds the repository to the database' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }
            .to output("\e[31mPlease provide a non-numeric ID for your custom repository.\e[0m\nCouldn't add custom repository.\n").to_stderr
            .and output('').to_stdout
        expect(Repository.find_by(external_url: external_url)).to be_nil
      end
    end

    context 'without parameters' do
      let(:argv) { ['add'] }

      it 'shows usage' do
        expect { command }.to output(/Usage:/).to_stderr
      end
    end

    context 'duplicate name' do
      subject(:custom_repo) { Repository.find_by(external_url: external_url) }

      let(:argv) { ['add', external_url, 'foo'] }

      before do
        create :repository, external_url: 'http://foo.bar', name: 'foobar', friendly_id: 'foo'
        expect { described_class.start(argv) }.to output("Successfully added custom repository.\n").to_stdout.and output('').to_stderr
      end

      it 'appends to the name to make the unique id' do
        expect(custom_repo.friendly_id).to eq('foo-1')
      end

      it 'keeps the name' do
        expect(custom_repo.name).to eq('foo')
      end
    end

    context 'duplicate id' do
      subject(:custom_repo) { Repository.find_by(external_url: external_url) }

      let(:argv) { ['add', external_url, 'bar', '--id', 'foo'] }

      it 'does not create a repository by the same id' do
        expect(described_class).to receive(:exit)
        expect do
          create :repository, external_url: 'http://foo.bar', name: 'foobar', friendly_id: 'foo'
          described_class.start(argv)
        end.to output("\e[31mA repository by the ID foo already exists.\e[0m\nCouldn't add custom repository.\n").to_stderr.and output('').to_stdout
        expect(Repository.find_by(external_url: external_url)).to be_nil
      end
    end

    context 'duplicate URL' do
      let(:argv) { ['add', external_url, 'foo'] }

      it 'does not update previous repository if non-custom' do
        expect(described_class).to receive(:exit)
        existing_repo = create :repository, external_url: external_url, name: 'foobar'
        expect do
          described_class.start(argv)
        end.to output("\e[31mA repository by the URL #{external_url} already exists (ID #{existing_repo.friendly_id}).\e[0m\nCouldn't add custom repository.\n")
                   .to_stderr
                   .and output('').to_stdout
        expect(Repository.find_by(external_url: external_url).name).to eq('foobar')
      end

      it 'handles trailing slashes' do
        expect(described_class).to receive(:exit)

        expect do
          described_class.start(%w[add http://example.com/repo/ foo])
        end.to output("Successfully added custom repository.\n").to_stdout.and output('').to_stderr
        existing_repo = Repository.find_by(external_url: 'http://example.com/repo/')
        expect do
          described_class.start(%w[add http://example.com/repo foo])
        end.to output("\e[31mA repository by the URL http://example.com/repo/ already exists (ID #{existing_repo.friendly_id})." \
          "\e[0m\nCouldn't add custom repository.\n")
                   .to_stderr
                   .and output('').to_stdout
      end

      it 'does not update previous repository if custom' do
        expect(described_class).to receive(:exit)
        existing_repo = create :repository, :custom, external_url: external_url, name: 'foobar'
        expect do
          described_class.start(argv)
        end.to output("\e[31mA repository by the URL #{external_url} already exists (ID #{existing_repo.friendly_id}).\e[0m\nCouldn't add custom repository.\n")
                   .to_stderr
                   .and output('').to_stdout
        expect(Repository.find_by(external_url: external_url).name).to eq('foobar')
      end
    end

    context 'URL with token' do
      let(:external_url) { 'http://example.com/repo?token' }
      let(:argv) { ['add', external_url, 'foo'] }

      it 'does not add trailing slash when query is given' do
        expect do
          described_class.start(argv)
        end.to output("Successfully added custom repository.\n").to_stdout.and output('').to_stderr

        expect(Repository.last.external_url.ends_with?('/')).to be_falsy
      end

      it 'stores the query parameter as an auth token' do
        expect do
          described_class.start(argv)
        end.to output("Successfully added custom repository.\n").to_stdout.and output('').to_stderr
        expect(Repository.last.auth_token.present?).to be_truthy
        expect(Repository.last.external_url).not_to include('?')
      end
    end
  end

  describe '#list' do
    shared_context 'rmt-cli custom repos list' do |command|
      let(:argv) { [command] }

      context 'empty repository list' do
        it 'says that there are not any custom repositories' do
          expect(described_class).to receive(:exit)
          expect { described_class.start(argv) }.to output("No custom repositories found.\n").to_stderr
        end
      end

      context 'products --csv' do
        let(:custom_repository) { create :repository, :custom, name: 'custom foo' }
        let(:argv) { [command, '--csv'] }
        let(:rows) do
          [[
            custom_repository.friendly_id,
            custom_repository.name,
            custom_repository.external_url,
            custom_repository.enabled,
            custom_repository.mirroring_enabled,
            custom_repository.last_mirrored_at
          ]]
        end
        let(:expected_output) do
          CSV.generate { |csv| rows.unshift(['ID', 'Name', 'URL', 'Mandatory?', 'Mirror?', 'Last Mirrored']).each { |row| csv << row } }
        end

        it 'outputs expected format' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout
        end
      end

      context 'with custom repository' do
        let(:custom_repository) { create :repository, :custom, name: 'custom foo' }
        let(:expected_output) do
          Terminal::Table.new(
            headings: ['ID', 'Name', 'URL', 'Mandatory?', 'Mirror?', 'Last Mirrored'],
            rows: [[
              custom_repository.friendly_id,
              custom_repository.name,
              custom_repository.external_url,
              custom_repository.enabled ? 'Mandatory' : 'Not Mandatory',
              custom_repository.mirroring_enabled ? 'Mirror' : "Don't Mirror",
              custom_repository.last_mirrored_at
            ]]
          ).to_s + "\n"
        end

        it 'displays the custom repo' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout
        end
      end
    end

    it_behaves_like 'rmt-cli custom repos list', 'list'
    it_behaves_like 'rmt-cli custom repos list', 'ls'
  end

  describe '#enable' do
    subject(:repository) { create :repository, :custom, :with_products }

    let(:command) do
      repository
      described_class.start(argv)
      repository.reload
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
        expect { command }.to output("Repository by ID 0 not found.\nRepository by ID 0 could not be found and was not enabled.\n")
                                  .to_stderr
                                  .and output('').to_stdout
      end

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'by repo id' do
      let(:argv) { ['enable', repository.id] }

      before { expect { command }.to output("Repository by ID #{repository.id} successfully enabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'by repo friendly_id' do
      let(:argv) { ['enable', repository.friendly_id] }

      before { expect { command }.to output("Repository by ID #{repository.friendly_id} successfully enabled.\n").to_stdout }

      its(:mirroring_enabled) { is_expected.to be(true) }
    end
  end

  describe '#disable' do
    subject(:repository) { create :repository, :custom, :with_products, mirroring_enabled: true }

    let(:command) do
      repository
      described_class.start(argv)
      repository.reload
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

      before do
        expect(described_class).to receive(:exit)
        expect { command }.to output("Repository by ID 0 not found.\nRepository by ID 0 could not be found and was not disabled.\n").to_stderr
                                  .and output('').to_stdout
      end

      its(:mirroring_enabled) { is_expected.to be(true) }
    end

    context 'by repo id' do
      let(:argv) { ['disable', repository.id] }
      let(:expected_output) do
        <<-OUTPUT
Repository by ID #{repository.id} successfully disabled.

\e[1mTo clean up downloaded files, please run 'rmt-cli repos clean'\e[22m
        OUTPUT
      end

      before { expect { command }.to output(expected_output).to_stdout }

      its(:mirroring_enabled) { is_expected.to be(false) }
    end

    context 'by repo friendly_id' do
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

  describe '#remove' do
    shared_context 'rmt-cli custom repos remove' do |command|
      let(:suse_repository) { create :repository, name: 'awesome-rmt-repo' }
      let(:custom_repository) { create :repository, :custom, name: 'custom foo' }

      context 'not found' do
        let(:argv) { [command, 'totally_wrong'] }

        before do
          expect(described_class).to receive(:exit)
          expect { described_class.start(argv) }.to output("Repository by ID totally_wrong not found.\n").to_stderr
        end

        it 'does not delete suse repository' do
          expect(Repository.find_by(id: suse_repository.id)).not_to be_nil
        end

        it 'does not delete custom repository' do
          expect(Repository.find_by(id: custom_repository.id)).not_to be_nil
        end
      end

      context 'non-custom repository' do
        let(:argv) { [command, suse_repository.friendly_id] }

        before do
          expect(described_class).to receive(:exit)
          expect { described_class.start(argv) }.to output("Repository by ID #{suse_repository.friendly_id} not found.\n").to_stderr
        end

        it 'does not delete suse non-custom repository' do
          expect(Repository.find_by(id: suse_repository.id)).not_to be_nil
        end
      end

      context 'custom repository by id' do
        let(:argv) { [command, custom_repository.id] }

        before do
          expect { described_class.start(argv) }.to output("Removed custom repository by ID #{custom_repository.id}.\n").to_stdout
        end

        it 'deletes custom repository' do
          expect(Repository.find_by(id: custom_repository.id)).to be_nil
        end
      end

      context 'custom repository by friendly_id' do
        let(:argv) { [command, custom_repository.friendly_id] }

        before do
          expect { described_class.start(argv) }.to output("Removed custom repository by ID #{custom_repository.friendly_id}.\n").to_stdout
        end

        it 'deletes custom repository' do
          expect(Repository.find_by(id: custom_repository.id)).to be_nil
        end
      end

      context 'custom repository with id starting with numbers' do
        let(:friendly_id) { "#{suse_repository.id}-repo-name" }
        let(:custom) { create :repository, :custom, friendly_id: friendly_id }

        let(:argv) { [command, custom.friendly_id] }

        before do
          expect { described_class.start(argv) }.to output("Removed custom repository by ID #{friendly_id}.\n").to_stdout
        end

        it 'deletes custom repository' do
          expect(Repository.find_by(friendly_id: friendly_id)).to be_nil
        end
      end
    end

    it_behaves_like 'rmt-cli custom repos remove', 'remove'
    it_behaves_like 'rmt-cli custom repos remove', 'rm'
  end

  describe '#attach' do
    context 'repository does not exist' do
      let(:argv) { ['attach', 'foo', product.id] }

      it 'fails' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }.to output("Repository by ID foo not found.\n").to_stderr.and output('').to_stdout
      end
    end

    context 'repository is from scc' do
      let(:repository) { create :repository }
      let(:argv) { ['attach', repository.friendly_id, product.id] }

      it('does not have an attached product') { expect(repository.products.count).to eq(0) }

      it 'fails' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }.to output("Repository by ID #{repository.friendly_id} not found.\n").to_stderr.and output('').to_stdout
        expect(repository.products.count).to eq(0)
      end
    end

    context 'product does not exist' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['attach', repository.friendly_id, 'foo'] }

      it('does not have an attached product') { expect(repository.products.count).to eq(0) }

      it 'fails' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }.to output("Cannot find product by ID foo.\n").to_stderr.and output('').to_stdout
        expect(repository.products.count).to eq(0)
      end
    end

    context 'product and repo exist by id' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['attach', repository.id, product.id] }

      it('does not have an attached product') { expect(repository.products.count).to eq(0) }

      it 'attaches the repository to the product' do
        expect { described_class.start(argv) }.to output('').to_stderr.and output("Attached repository to product '#{product.name}'.\n").to_stdout
        expect(repository.products.first.id).to eq(product.id)
      end
    end

    context 'product and repo exist by friendly_id' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['attach', repository.friendly_id, product.id] }

      it('does not have an attached product') { expect(repository.products.count).to eq(0) }

      it 'attaches the repository to the product' do
        expect { described_class.start(argv) }.to output('').to_stderr.and output("Attached repository to product '#{product.name}'.\n").to_stdout
        expect(repository.products.first.id).to eq(product.id)
      end
    end
  end

  describe '#detach' do
    context 'repository does not exist' do
      let(:argv) { ['detach', 'foo', product.id] }

      it 'fails' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }.to output("Repository by ID foo not found.\n").to_stderr.and output('').to_stdout
      end
    end

    context 'repository is from scc' do
      let(:repository) { create :repository }
      let(:argv) { ['detach', 'foo', repository.friendly_id] }

      before do
        repository_service.attach_product!(product, repository)
      end

      it('has an attached product') { expect(repository.products.count).to eq(1) }

      it 'fails' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }.to output("Repository by ID foo not found.\n").to_stderr.and output('').to_stdout
        expect(repository.products.count).to eq(1)
      end
    end

    context 'product does not exist' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['detach', repository.friendly_id, 'foo'] }

      before do
        repository_service.attach_product!(product, repository)
      end

      it('has an attached product') { expect(repository.products.count).to eq(1) }

      it 'fails' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }.to output("Cannot find product by ID foo.\n").to_stderr.and output('').to_stdout
        expect(repository.products.count).to eq(1)
      end
    end

    context 'product and repo exist by id' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['detach', repository.id, product.id] }

      before do
        repository_service.attach_product!(product, repository)
      end

      it('has an attached product') { expect(repository.products.count).to eq(1) }

      it 'detaches the repository from the product' do
        expect { described_class.start(argv) }.to output('').to_stderr.and output("Detached repository from product '#{product.name}'.\n").to_stdout
        expect(repository.products.count).to eq(0)
      end
    end

    context 'product and repo exist by friendly_id' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['detach', repository.friendly_id, product.id] }

      before do
        repository_service.attach_product!(product, repository)
      end

      it('has an attached product') { expect(repository.products.count).to eq(1) }

      it 'detaches the repository from the product' do
        expect { described_class.start(argv) }.to output('').to_stderr.and output("Detached repository from product '#{product.name}'.\n").to_stdout
        expect(repository.products.count).to eq(0)
      end
    end
  end

  describe '#products' do
    context 'scc repository' do
      let(:repository) { create :repository }
      let(:argv) { ['product', repository.friendly_id] }

      before do
        repository_service.attach_product!(product, repository)
      end

      it('has an attached product') { expect(repository.products.count).to eq(1) }

      it 'does not displays the product' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }.to output("Repository by ID #{repository.friendly_id} not found.\n").to_stderr.and output('').to_stdout
      end
    end

    context 'custom repository with products' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['products', repository.friendly_id] }
      let(:rows) do
        [[
          product.id,
          product.name,
          product.version,
          product.arch
        ]]
      end
      let(:expected_output) do
        Terminal::Table.new(
          headings: ['Product ID', 'Product Name', 'Product Version', 'Product Architecture'],
          rows: rows
        ).to_s + "\n"
      end

      before do
        repository_service.attach_product!(product, repository)
      end

      it('has an attached product') { expect(repository.products.count).to eq(1) }

      it 'displays the product' do
        expect { described_class.start(argv) }.to output(expected_output).to_stdout
      end

      describe 'products --csv' do
        let(:argv) { ['products', repository.friendly_id, '--csv'] }
        let(:expected_output) do
          CSV.generate { |csv| rows.unshift(['ID', 'Name', 'Version', 'Architecture']).each { |row| csv << row } }
        end

        it 'outputs expected format' do
          expect { command }.to output(expected_output).to_stdout
        end
      end
    end

    context 'custom repository without products' do
      let(:repository) { create :repository, :custom }
      let(:argv) { ['products', repository.friendly_id] }

      it('does not have an attached product') { expect(repository.products.count).to eq(0) }

      it 'displays the product' do
        expect(described_class).to receive(:exit)
        expect { described_class.start(argv) }.to output('').to_stdout.and output("No products attached to repository.\n").to_stderr
      end
    end
  end
end
