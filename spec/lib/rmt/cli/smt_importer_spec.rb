require 'rails_helper'
require 'rmt/cli/smt_importer'

describe SMTImporter do
  let(:data_dir) { File.join(Dir.pwd, 'spec/fixtures/files/csv') }
  let(:no_systems) { false }
  let(:importer) { described_class.new(data_dir, no_systems) }

  describe '#read_csv' do
    let(:login) { 'SCC_620a989bc9fb44cc95e7f96390bd979e' }
    let(:product_id) { '1421' }

    context 'when CSV file exists' do
      it 'returns the parsed values as array' do
        expect(importer.read_csv('activations')).to be_a(CSV)
        expect(importer.read_csv('activations').first).to eq([login, product_id])
        expect(importer.read_csv('activations').count).to be(2)
      end
    end

    context 'when CSV file does not exist' do
      it 'raises an error' do
        expect { importer.read_csv('not_existing') }.to raise_exception(Errno::ENOENT)
      end
    end
  end

  describe '#import_repositories' do
    before do
      allow(importer).to receive(:read_csv).with('enabled_repos').and_return enabled_repos
    end

    let(:repo_1) { create :repository }
    let(:repo_2) { create :repository }

    context 'when repository exists' do
      let(:enabled_repos) { [repo_1.scc_id, repo_2.scc_id] }

      it 'enables mirroring for given repositories' do
        expect { importer.import_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stdout
          Enabled mirroring for repository #{repo_1.scc_id}
          Enabled mirroring for repository #{repo_2.scc_id}
        OUTPUT

        expect(repo_1.reload.mirroring_enabled).to be(true)
        expect(repo_2.reload.mirroring_enabled).to be(true)
      end
    end


    context 'when repository does not exists' do
      let(:enabled_repos) { [0] }

      it 'shows a warning' do
        expect { importer.import_repositories }.to output(/Repository 0 was not found in RMT/).to_stderr
      end
    end
  end

  describe '#import_custom_repositories' do
    before do
      allow(importer).to receive(:read_csv).with('enabled_custom_repos').and_return enabled_custom_repos
    end

    context 'already created repository' do
      let(:repo) { create :repository, :custom, external_url: 'https://something.org/repos/sles15/' }
      let(:product_1) { create :product, :with_service }
      let(:product_2) { create :product, :with_service }

      let(:enabled_custom_repos) do
        [
          [product_1.id, repo.name, repo.external_url],
          [product_2.id, repo.name, repo.external_url]
        ]
      end

      it 'adds the association between repository and product if neccesary' do
        expect { importer.import_custom_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stdout
          Added association between #{repo.name} and product #{product_1.id}
          Added association between #{repo.name} and product #{product_2.id}
        OUTPUT
        expect(repo.services.find_by(id: product_1.service)).not_to be_nil
        expect(repo.services.find_by(id: product_2.service)).not_to be_nil
      end
    end

    context 'repository not created yet' do
      let(:product) { create :product, :with_service }
      let(:repo_name) { 'SAMPLE_REPO' }
      let(:repo_url) { 'https://SAMPLE_REPO_URL/repo/' }
      let(:local_path) { '/srv/repos/repo/' }

      let(:enabled_custom_repos) { [[product.id, repo_name, repo_url]] }

      it 'creates the repository and associations' do
        expect(Repository).to receive(:make_local_path).with(repo_url).and_return local_path

        expect { importer.import_custom_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stdout
          Added association between #{repo_name} and product #{product.id}
        OUTPUT

        repo = Repository.find_by(external_url: repo_url, local_path: local_path)
        expect(repo).not_to be_nil
        expect(repo.services.find_by(id: product.service)).not_to be_nil
      end

      context 'without trailing slash' do
        let(:repo_url) { 'https://SAMPLE_REPO_URL/repo' }

        it 'adds a trailing slash' do
          expect(Repository).to receive(:make_local_path).with(repo_url + '/').and_return local_path

          expect { importer.import_custom_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stdout
            Added association between #{repo_name} and product #{product.id}
          OUTPUT
          repo = Repository.find_by(external_url: repo_url + '/', local_path: local_path)
          expect(repo).not_to be_nil
          expect(repo.services.find_by(id: product.service)).not_to be_nil
        end
      end
    end

    context 'without a valid product' do
      let(:repo) { create :repository, :custom }

      let(:enabled_custom_repos) { [[0, repo.name, repo.external_url]] }

      it 'shows a warning' do
        expect { importer.import_custom_repositories }.to output(<<-OUTPUT.strip_heredoc).to_stderr
          Product 0 not found!
          Tried to attach custom repository #{repo.name} to product 0,
          but that product was not found. Attach it to a different product
          by running 'rmt-cli repos custom attach'
        OUTPUT
      end
    end
  end

  describe '#import_systems' do
    before do
      allow(importer).to receive(:read_csv).with('systems').and_return systems
    end

    let(:system_1) { ['system_1_login', 'system_1_pw', 'system_1_hn', '1526448710'] }
    let(:system_2) { ['system_2_login', 'system_2_pw', 'system_2_hn', '1526468710'] }
    let(:system_3) { ['system_3_login', 'system_3_pw', 'system_3_hn', '1526458710'] }

    let(:systems) { [system_1, system_2, system_2, system_3] }

    it 'creates new systems for the given credentials' do
      expect { importer.import_systems }.to output("Imported 3 systems\n").to_stdout.and(
        output("Duplicate entry for system system_2_login, skipping\n").to_stderr
      )
      expect(System.find_by(login: system_1[0], password: system_1[1])).not_to be_nil
      expect(System.find_by(login: system_3[0], password: system_3[1])).not_to be_nil
      expect(System.find_by(login: system_1[0], password: system_1[1]).registered_at.to_i).to eq(system_1[3].to_i)
    end
  end

  describe '#import_activations' do
    before do
      allow(importer).to receive(:read_csv).with('activations').and_return activations
    end

    let(:product) { create :product, :with_service }

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
        expect do
          importer.load_systems
          importer.import_activations
        end.to output("Imported 3 activations\n").to_stdout
        expect(Activation.find_by(system: system_1, service: product.service)).not_to be_nil
        expect(Activation.find_by(system: system_2, service: product.service)).not_to be_nil
        expect(Activation.find_by(system: system_3, service: product.service)).not_to be_nil
      end
    end

    context 'when a system does not exist' do
      let(:activations) { [['NOT_EXISTING', product.id]] }

      it 'does not create an activation' do
        expect(Activation).not_to receive(:create)
        expect { importer.import_activations }.to output(<<-OUTPUT.strip_heredoc).to_stderr
          System NOT_EXISTING not found
        OUTPUT
      end
    end

    context 'when a product does not exist' do
      let(:system) { create :system }
      let(:activations) { [[system.login, 0]] }

      it 'does not create an activation' do
        expect(Activation).not_to receive(:create)
        expect do
          importer.load_systems
          importer.import_activations
        end.to output(<<-OUTPUT.strip_heredoc).to_stderr
          Product 0 not found
        OUTPUT
      end
    end
  end

  describe '#import_hardware_info' do
    it 'warns the user about missing systems to add the hw_info to' do
      expect { importer.import_hardware_info }.to output(<<-OUTPUT.strip_heredoc).to_stderr
        System SCC_620a989bc9fb44cc95e7f96390bd979e not found
        System SCC_82660967a72c4c6f9567cd2382b232b9 not found
      OUTPUT
    end

    it 'reads all hardware info and creates or updates the info accordingly' do
      # The systems has to be created before attaching hw_info to it
      create :system, login: 'SCC_620a989bc9fb44cc95e7f96390bd979e'
      create :system, login: 'SCC_82660967a72c4c6f9567cd2382b232b9'

      expect { importer.import_hardware_info }.to output(<<-OUTPUT.strip_heredoc).to_stdout
        Hardware information stored for system SCC_620a989bc9fb44cc95e7f96390bd979e
        Hardware information stored for system SCC_82660967a72c4c6f9567cd2382b232b9
      OUTPUT
    end
  end
  describe '#run' do
    context 'without --no-system and --no-hwinfo flags' do
      it 'runs all steps including importing the systems' do
        expect(importer).to receive(:check_products_exist)
        expect(importer).to receive(:import_repositories)
        expect(importer).to receive(:import_custom_repositories)
        expect(importer).to receive(:import_systems)
        expect(importer).to receive(:import_activations)
        expect(importer).to receive(:import_hardware_info)
        importer.run ['-d', 'foo']
      end
    end
    context 'with --no-system flag' do
      it 'imports only the repositories and not the systems' do
        expect(importer).to receive(:check_products_exist)
        expect(importer).to receive(:import_repositories)
        expect(importer).to receive(:import_custom_repositories)
        expect(importer).not_to receive(:import_systems)
        expect(importer).not_to receive(:import_activations)
        expect(importer).not_to receive(:import_hardware_info)
        importer.run ['--no-systems', '-d', 'foo']
      end
    end
    context 'with --no-system flag' do
      it 'imports repositories and systems without hwinfo' do
        expect(importer).to receive(:check_products_exist)
        expect(importer).to receive(:import_repositories)
        expect(importer).to receive(:import_custom_repositories)
        expect(importer).to receive(:import_systems)
        expect(importer).to receive(:import_activations)
        expect(importer).not_to receive(:import_hardware_info)
        importer.run ['--no-hwinfo', '-d', 'foo']
      end
    end
  end

  describe '#parse_cli_arguments' do
    let(:importer) { described_class.new(nil, nil) }

    it 'parses a valid input and sets the confiurations accordingly' do
      importer.parse_cli_arguments ['-d', 'foo', '--no-systems']
      expect(importer.data_dir).to eq('foo')
      expect(importer.no_systems).to be(true)
    end

    it 'shows the help output when invalid arguments supplied' do
      expect do
        expect { importer.parse_cli_arguments ['--nope-nope'] }.to raise_exception SMTImporter::ImportException
      end.to output(<<-OUTPUT.strip_heredoc).to_stdout
        Usage: rspec [options]
            -d, --data PATH                  Path to unpacked SMT data tarball
                --no-systems                 Do not import the systems that were registered to the SMT
                --no-hwinfo                  Do not import system hardware info from MachineData table
      OUTPUT
    end
  end

  describe '#check_products_exist' do
    it 'warns and exits if no product exists' do
      expect do
        expect { importer.check_products_exist }.to raise_exception SMTImporter::ImportException
      end.to output(<<-OUTPUT.strip_heredoc).to_stderr
        RMT has not been synced to SCC yet. Please run 'rmt-cli sync' before
        importing data from SMT.
      OUTPUT
    end

    it 'checks if at least one product exists' do
      create :product, :with_service
      expect { importer.check_products_exist }.not_to raise_error
    end
  end
end
