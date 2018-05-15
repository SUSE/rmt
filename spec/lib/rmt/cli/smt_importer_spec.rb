require 'rails_helper'
require 'rmt/cli/smt_importer'

describe SMTImporter do
  let(:config) do
    config = OpenStruct.new
    config.data_dir = File.join(Dir.pwd, 'spec/fixtures/files/csv')
    config.no_systems = false
    config
  end

  let(:script) { described_class.new(config) }

  describe '#read_csv' do
    let(:login) { 'SCC_620a989bc9fb44cc95e7f96390bd979e' }
    let(:product_id) { '1421' }

    it 'reads the file by tabs and returns the parsed values as array' do
      expect(script.read_csv('activations')).to be_a(CSV)
      expect(script.read_csv('activations').first).to eq([login, product_id])
      expect(script.read_csv('activations').count).to be(2)
    end

    it 'throws when the file could not be found' do
      expect { script.read_csv('not_existing') }.to raise_exception(Errno::ENOENT)
    end
  end

  describe '#import_repositories' do
    before do
      allow(script).to receive(:read_csv).with('enabled_repos').and_return enabled_repos
    end

    let(:repo_1) { create :repository }
    let(:repo_2) { create :repository }

    context 'with repository' do
      let(:enabled_repos) { [repo_1.scc_id, repo_2.scc_id] }

      it 'enables mirroring for given repositories' do
        expect { script.import_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stdout
          Enabled mirroring for repository #{repo_1.scc_id}
          Enabled mirroring for repository #{repo_2.scc_id}
        OUTPUT

        expect(repo_1.reload.mirroring_enabled).to be(true)
        expect(repo_2.reload.mirroring_enabled).to be(true)
      end
    end


    context 'without repository' do
      let(:enabled_repos) { [0] }

      it 'warns the user if the repository was not found' do
        expect { script.import_repositories }.to output(/Repository 0, perhaps you no longer/).to_stderr
      end
    end
  end

  describe '#import_custom_repositories' do
    before do
      allow(script).to receive(:read_csv).with('enabled_custom_repos').and_return enabled_custom_repos
    end

    context 'already created repository' do
      let(:repo) { create :repository, :custom }
      let(:product_1) { create :product }
      let(:product_2) { create :product }

      let(:enabled_custom_repos) do
        [
          [product_1.id, repo.name, repo.external_url],
          [product_2.id, repo.name, repo.external_url]
        ]
      end

      it 'adds the association between repository and product if neccesary' do
        expect { script.import_custom_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stdout
          Added association between #{repo.name} and product #{product_1.id}
          Added association between #{repo.name} and product #{product_2.id}
        OUTPUT
        expect(RepositoriesServicesAssociation.find_by(service: product_1.service, repository: repo)).not_to be_nil
        expect(RepositoriesServicesAssociation.find_by(service: product_2.service, repository: repo)).not_to be_nil
      end
    end

    context 'repository not created yet' do
      let(:product) { create :product }
      let(:repo_name) { 'SAMPLE_REPO' }
      let(:repo_url) { 'https://SAMPLE_REPO_URL/repo/...' }
      let(:local_path) { '/srv/repos/SAMPLE_REPO_URL' }

      let(:enabled_custom_repos) { [[product.id, repo_name, repo_url]] }

      it 'creates the repository if not created' do
        expect(Repository).to receive(:make_local_path).with(repo_url).and_return local_path

        expect { script.import_custom_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stdout
          Added association between #{repo_name} and product #{product.id}
        OUTPUT

        expect(Repository.find_by(external_url: repo_url, local_path: local_path)).not_to be_nil
      end
    end

    context 'without a valid product' do
      let(:repo) { create :repository, :custom }

      let(:enabled_custom_repos) { [[0, repo.name, repo.external_url]] }

      it 'warns the user if the desired product was not found' do
        expect { script.import_custom_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stderr
          Product 0 not found
        OUTPUT
      end
    end
  end

  describe '#import_systems' do
    before do
      allow(script).to receive(:read_csv).with('systems').and_return systems
    end

    let(:system_1) { ['system_1_login', 'system_1_pw', 'system_1_hn'] }
    let(:system_2) { ['system_2_login', 'system_2_pw', 'system_2_hn'] }
    let(:system_3) { ['system_3_login', 'system_3_pw', 'system_3_hn'] }

    let(:systems) { [system_1, system_2, system_3] }

    it 'creates new systems for the given credentials' do
      expect { script.import_systems }.to output(<<-OUTPUT.strip_heredoc).to_stdout
        Imported system #{system_1[0]}
        Imported system #{system_2[0]}
        Imported system #{system_3[0]}
      OUTPUT
      expect(System.find_by(login: system_1[0], password: system_1[1])).not_to be_nil
      expect(System.find_by(login: system_2[0], password: system_2[1])).not_to be_nil
      expect(System.find_by(login: system_3[0], password: system_3[1])).not_to be_nil
    end
  end

  describe '#import_activations' do
    before do
      allow(script).to receive(:read_csv).with('activations').and_return activations
    end

    let(:product) { create :product }

    context 'with systems' do
      let(:system_1) { create :system }
      let(:system_2) { create :system }
      let(:system_3) { create :system }

      let(:activations) do
        [
          [system_1.login, product.id],
          [system_2.login, product.id],
          [system_3.login, product.id]
        ]
      end

      it 'creates the activations for the systems' do
        expect { script.import_activations }.to output(<<-OUTPUT.strip_heredoc).to_stdout
          Imported activation of #{product.id} for #{system_1.login}
          Imported activation of #{product.id} for #{system_2.login}
          Imported activation of #{product.id} for #{system_3.login}
        OUTPUT
        expect(Activation.find_by(system: system_1, service: product.service)).not_to be_nil
        expect(Activation.find_by(system: system_2, service: product.service)).not_to be_nil
        expect(Activation.find_by(system: system_3, service: product.service)).not_to be_nil
      end
    end

    context 'without a system' do
      let(:activations) { [['NOT_EXISTING', product.id]] }

      it 'does not create a activation for a not existing system' do
        expect(Activation).not_to receive(:create)
        expect { script.import_activations }.to output(<<-OUTPUT.strip_heredoc).to_stderr
          System NOT_EXISTING not found
        OUTPUT
      end
    end

    context 'without a product' do
      let(:system) { create :system }
      let(:activations) { [[system.login, 0]] }

      it 'does not create a activation for a not existing system' do
        expect(Activation).not_to receive(:create)
        expect { script.import_activations }.to output(<<-OUTPUT.strip_heredoc).to_stderr
          Product 0 not found
        OUTPUT
      end
    end
  end

  describe '#import_hardware_info' do
    it 'warns the user about missing systems to add the hw_info to' do
      expect { script.import_hardware_info }.to output(<<-OUTPUT.strip_heredoc).to_stderr
        System SCC_620a989bc9fb44cc95e7f96390bd979e not found
        System SCC_82660967a72c4c6f9567cd2382b232b9 not found
      OUTPUT
    end

    it 'reads all hardware info and creates or updates the info accordingly' do
      # The systems has to be created before attaching hw_info to it
      create :system, login: 'SCC_620a989bc9fb44cc95e7f96390bd979e'
      create :system, login: 'SCC_82660967a72c4c6f9567cd2382b232b9'

      expect { script.import_hardware_info }.to output(<<-OUTPUT.strip_heredoc).to_stdout
        Hardware information stored for system SCC_620a989bc9fb44cc95e7f96390bd979e
        Hardware information stored for system SCC_82660967a72c4c6f9567cd2382b232b9
      OUTPUT
    end
  end


  # rubocop:disable RSpec/MultipleExpectations
  describe '#run' do
    it 'runs all steps including importing the systems' do
      expect(script).to receive(:check_products_exist)
      expect(script).to receive(:import_repositories)
      expect(script).to receive(:import_custom_repositories)
      expect(script).to receive(:import_systems)
      expect(script).to receive(:import_activations)
      expect(script).to receive(:import_hardware_info)
      script.run ['-d', 'foo']
    end
    it 'imports only the repositories and not the systems' do
      expect(script).to receive(:check_products_exist)
      expect(script).to receive(:import_repositories)
      expect(script).to receive(:import_custom_repositories)
      expect(script).not_to receive(:import_systems)
      expect(script).not_to receive(:import_activations)
      expect(script).not_to receive(:import_hardware_info)
      expect { script.run ['--no-systems', '-d', 'foo'] }.to raise_exception SMTImporter::ImportException
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  describe '#parse_cli_arguments' do
    let(:config) do
      config = OpenStruct.new
      config.data_dir = nil
      config.no_systems = nil
      config
    end

    let(:script) { described_class.new(config) }

    it 'parses a valid input and sets the confiurations accordingly' do
      script.parse_cli_arguments ['-d', 'foo', '--no-systems']
      expect(script.config.data_dir).to eq('foo')
      expect(script.config.no_systems).to be(true)
    end

    it 'shows the help output when invalid arguments supplied' do
      expect do
        expect { script.parse_cli_arguments ['--nope-nope'] }.to raise_exception SMTImporter::ImportException
      end.to output(<<-OUTPUT.strip_heredoc).to_stdout
        Usage: rspec [options]
            -d, --data PATH                  Path to unpacked SMT data tarball
                --no-systems                 Import no systems to rmt
      OUTPUT
    end
  end

  describe '#check_products_exist' do
    it 'warns and exits if no product exists' do
      expect do
        expect { script.check_products_exist }.to raise_exception SMTImporter::ImportException
      end.to output(<<-OUTPUT.strip_heredoc).to_stderr
        No products has been found in rmt. Please run rmt-cli sync before
        importing data from smt.
      OUTPUT
    end

    it 'checks if at least one product exists' do
      create :product
      expect { script.check_products_exist }.not_to raise_error
    end
  end
end
