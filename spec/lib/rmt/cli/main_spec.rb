require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe RMT::CLI::Main do
  subject(:command) { described_class.start(argv) }

  let(:argv) { [] }

  describe '.start' do
    describe 'sync' do
      let(:argv) { ['sync'] }

      it 'triggers sync' do
        expect_any_instance_of(RMT::SCC).to receive(:sync)
        command
      end
    end

    describe 'help' do
      let(:argv) { ['help'] }

      it 'displays help' do
        expect { command }.to output(/Commands:/).to_stdout
      end
    end

    ['version', '-v', '--version'].each do |version|
      describe version do
        let(:argv) { [version] }

        it 'displays version' do
          expect { command }.to output("#{RMT::VERSION}\n").to_stdout
        end
      end
    end

    describe 'mirror' do
      let(:argv) { ['mirror'] }

      before { create :product, :with_mirrored_repositories }

      it 'triggers mirroring of enabled repos' do
        expect_any_instance_of(RMT::CLI::Mirror).to receive(:repos)
        command
      end
    end

    describe 'mirror custom' do
      let(:repo_url) { 'http://example.com/repo/' }
      let(:argv) { ['mirror', 'custom', repo_url] }

      it 'triggers mirroring of a custom repo' do
        expect_any_instance_of(RMT::CLI::Mirror).to receive(:mirror_one_repo).with(repo_url, Repository.make_local_path(repo_url)).once
        command
      end

      context 'with local_path as extra parameter' do
        let(:local_path) { 'custom/dummy/repo/' }
        let(:argv) { ['mirror', 'custom', repo_url, local_path] }

        it 'triggers mirroring of a custom repo to a custom path' do
          expect_any_instance_of(RMT::CLI::Mirror).to receive(:mirror_one_repo).with(repo_url, local_path).once
          command
        end
      end
    end

    describe 'exception handling' do
      let(:exception_class) { RMT::CLI::Error }
      let(:error_message) { 'Dummy error' }

      before do
        expect_any_instance_of(described_class).to receive(:help) { raise exception_class, error_message }
        expect(described_class).to receive(:exit)
      end

      context 'without --debug' do
        it 'prints exception short message' do
          expect { command }.to output("#{error_message}\n").to_stderr
        end
      end

      context 'with --debug' do
        let(:argv) { ['--debug'] }

        it 'prints exception details' do
          expect { command }.to output(/#<RMT::CLI::Error: #{error_message}>/).to_stderr
        end
      end

      describe 'error cases' do
        describe 'Mysql2::Error with access denied error' do
          let(:exception_class) { Mysql2::Error }
          let(:error_message) { 'Access denied for user `rmt`@`localhost`' }

          it 'outputs custom error message' do
            expect { command }.to output(
              "Cannot connect to database server. Make sure its credentials are configured in '/etc/rmt.conf'.\n"
            ).to_stderr
          end
        end

        describe 'Mysql2::Error with cannot connect error' do
          let(:exception_class) { Mysql2::Error }
          let(:error_message) { "Can't connect to local MySQL server through socket '/var/run/mysql/mysql.sock'" }

          it 'outputs custom error message' do
            expect { command }.to output(
              "Cannot connect to database server. Make sure it is running and its credentials are configured in '/etc/rmt.conf'.\n"
            ).to_stderr
          end
        end

        describe 'ActiveRecord::NoDatabaseError with access denied error' do
          let(:exception_class) { ActiveRecord::NoDatabaseError }

          it 'outputs custom error message' do
            expect { command }.to output(
              "The RMT database has not yet been initialized. Run 'systemctl start rmt-migration' to setup the database.\n"
            ).to_stderr
          end
        end

        describe 'RMT::SCC::CredentialsError with access denied error' do
          let(:exception_class) { RMT::SCC::CredentialsError }

          it 'outputs custom error message' do
            expect { command }.to output(
              "The SCC credentials are not configured correctly in '/etc/rmt.conf'. You can obtain them from https://scc.suse.com/organization\n"
            ).to_stderr
          end
        end

        describe 'SUSE::Connect::Api::InvalidCredentialsError with access denied error' do
          let(:exception_class) { SUSE::Connect::Api::InvalidCredentialsError }

          it 'outputs custom error message' do
            expect { command }.to output(
              "The SCC credentials are not configured correctly in '/etc/rmt.conf'. You can obtain them from https://scc.suse.com/organization\n"
            ).to_stderr
          end
        end
      end
    end

    describe 'exceptions we do not catch' do
      before do
        expect_any_instance_of(described_class).to receive(:help) { raise exception_class, error_message }
      end

      describe 'Mysql2::Error with other error messages' do
        let(:exception_class) { Mysql2::Error }
        let(:error_message) { 'Error in SQL query' }

        it 'raises an exception' do
          expect { command }.to raise_exception(Mysql2::Error)
        end
      end
    end
  end
end
