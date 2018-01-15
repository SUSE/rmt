require 'rails_helper'

# rubocop:disable RSpec/MultipleExpectations

describe RMT::CLI::CustomRepos do
  subject(:command) { described_class.start(argv) }

  let(:product) { create :product }
  let(:external_url) { 'http://example.com/repos' }

  [
    {
      name: 'short',
      options: {
        name: '-n',
        product_id: '-p',
        url: '-u'
      }
    },
    {
      name: 'long',
      options: {
        name: '--name',
        product_id: '--product-id',
        url: '--url'
      }
    }
  ].each do |add_run|
    describe "add #{add_run[:name]}" do
      let(:option_url) { add_run[:options][:url] }
      let(:option_product_id) { add_run[:options][:product_id] }
      let(:option_name) { add_run[:options][:name] }

      context 'product does not exist' do
        let(:argv) { ['add', option_product_id, 'foobarz', option_url, external_url, option_name, 'foo'] }

        it 'does not add the repository to the database' do
          expect { described_class.start(argv) }.to output("Cannot find product by id foobarz.\n").to_stderr
          expect(Repository.find_by(name: 'foo')).to be_nil
        end
      end

      context 'product exists' do
        let(:argv) { ['add', option_product_id, product.id, option_url, external_url, option_name, 'foo'] }

        it 'adds the repository to the database' do
          expect { described_class.start(argv) }.to output("Successfully added custom repository.\n").to_stdout.and output('').to_stderr
          expect(Repository.find_by(name: 'foo')).not_to be_nil
        end
      end

      context 'invalid URL' do
        let(:argv) { ['add', option_product_id, product.id, option_url, 'http://foo.bar', option_name, 'foo'] }

        it 'adds the repository to the database' do
          expect { described_class.start(argv) }.to output("Invalid URL \"http://foo.bar\" provided.\n").to_stderr.and output('').to_stdout
          expect(Repository.find_by(name: 'foo')).to be_nil
        end
      end

      context 'duplicate URL' do
        it 'does not add duplicate record to repository' do
          argv = ['add', option_product_id, product.id, option_url, external_url, option_name, 'foo']
          expect do
            create :repository, :custom, external_url: external_url
            described_class.start(argv)
          end.to output("A repository by URL \"#{external_url}\" already exists.\n").to_stderr.and output('').to_stdout
        end

        it 'updates previous repository on --update' do
          argv = ['add', option_product_id, product.id, option_url, external_url, option_name, 'foo', '--update']
          expect do
            create :repository, :custom, external_url: external_url, name: 'foobar'
            described_class.start(argv)
          end.to output("Successfully updated custom repository.\n").to_stdout.and output('').to_stderr
          expect(Repository.find_by(external_url: external_url).name).to eq('foo')
        end

        it 'does not update previous repository if non-custom' do
          argv = ['add', option_product_id, product.id, option_url, external_url, option_name, 'foo', '--update']
          expect do
            create :repository, external_url: external_url, name: 'foobar'
            described_class.start(argv)
          end.to output("A non-custom repository by URL \"http://example.com/repos\" already exists.\n").to_stderr.and output('').to_stdout
          expect(Repository.find_by(external_url: external_url).name).to eq('foobar')
        end
      end
    end
  end

  %w[list ls].each do |command|
    describe command do
      let(:argv) { [command] }

      context 'empty repository list' do
        it 'says that there are not any custom repositories' do
          expect { described_class.start(argv) }.to output("No custom repositories found.\n").to_stderr
        end
      end

      context 'with custom repository' do
        let(:custom_repository) { create :repository, :custom, name: 'custom foo' }

        it 'displays the custom repo' do
          expect { described_class.start(argv) }.to output(/.*#{custom_repository.name}.*/).to_stdout
        end
      end
    end
  end


  %w[remove rm].each do |command|
    describe command do
      let(:suse_repository) { create :repository, name: 'awesome-rmt-repo' }
      let(:custom_repository) { create :repository, :custom, name: 'custom foo' }

      context 'not found' do
        let(:argv) { [command, 'totally_wrong'] }

        before do
          expect { described_class.start(argv) }.to output(
            "Cannot find custom repository by id \"totally_wrong\".\n"
                                                    ).to_stderr
        end
        it 'does not delete suse repository' do
          expect(Repository.find_by(id: suse_repository.id)).not_to be_nil
        end

        it 'does not delete custom repository' do
          expect(Repository.find_by(id: custom_repository.id)).not_to be_nil
        end
      end

      context 'non-custom repository' do
        let(:argv) { [command, suse_repository.id] }

        before do
          expect { described_class.start(argv) }.to output("Cannot remove non-custom repositories.\n").to_stderr
        end

        it 'does not delete suse non-custom repository' do
          expect(Repository.find_by(id: suse_repository.id)).not_to be_nil
        end
      end

      context 'non-custom repository' do
        let(:argv) { [command, custom_repository.id] }

        before do
          expect { described_class.start(argv) }.to output("Removed custom repository by id \"#{custom_repository.id}\".\n").to_stdout
        end

        it 'deletes custom repository' do
          expect(Repository.find_by(id: custom_repository.id)).to be_nil
        end
      end
    end
  end
end
