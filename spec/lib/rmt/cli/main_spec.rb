require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe RMT::CLI::Main do
  subject(:command) { described_class.start(argv) }

  describe '.start' do
    context 'help' do
      let(:argv) { ['help'] }

      it 'displays help' do
        expect { command }.to output(/Commands:/).to_stdout
      end
    end

    context 'version argument' do
      let(:argv) { ['version'] }

      it 'displays version' do
        expect { command }.to output("#{RMT::VERSION}\n").to_stdout
      end
    end

    context 'version -v option' do
      let(:argv) { ['-v'] }

      it 'displays version' do
        expect { command }.to output("#{RMT::VERSION}\n").to_stdout
      end
    end

    context 'version --version option' do
      let(:argv) { ['--version'] }

      it 'displays version' do
        expect { command }.to output("#{RMT::VERSION}\n").to_stdout
      end
    end

    context 'mirror' do
      let(:argv) { ['mirror'] }

      it 'calls RMT::CLI::Mirror' do
        expect(RMT::CLI::Mirror).to receive(:mirror)
        command
      end
    end

    context 'with repo_url as parameter' do
      let(:repo_url) { 'http://example.com/repo/' }
      let(:argv) { ['mirror', repo_url] }

      it 'calls RMT::CLI::Mirror' do
        expect(RMT::CLI::Mirror).to receive(:mirror_one_repo).with(repo_url, '/repo/').at_least(:once)
        command
      end
    end

    context 'with repo_url and local_path as parameters' do
      let(:repo_url) { 'http://example.com/repo/' }
      let(:local_path) { 'custom/dummy/repo/' }
      let(:argv) { ['mirror', repo_url, local_path] }

      it 'calls RMT::CLI::Mirror' do
        expect(RMT::CLI::Mirror).to receive(:mirror_one_repo).with(repo_url, local_path).at_least(:once)
        command
      end
    end

    context 'handles exceptions without --debug' do
      let(:argv) { ['mirror'] }

      before do
        expect(RMT::CLI::Mirror).to receive(:mirror) { raise RMT::CLI::Error, 'Dummy exception' }
        expect(described_class).to receive(:exit)
      end

      it 'prints exception short message' do
        expect { command }.to output("Dummy exception\n").to_stderr
      end
    end

    context 'handles exceptions with --debug' do
      let(:argv) { ['mirror', '--debug'] }

      before do
        expect(RMT::CLI::Mirror).to receive(:mirror) { raise RMT::CLI::Error, 'Dummy exception' }
        expect(described_class).to receive(:exit)
      end

      it 'prints exception details' do
        expect { command }.to output(/#<RMT::CLI::Error: Dummy exception>/).to_stderr
      end
    end

    describe '.handle_exceptions' do
      let(:argv) { ['mirror'] }
      let(:error_message) { 'Dummy error' }

      context do
        before do
          expect(RMT::CLI::Mirror).to receive(:mirror) { raise exception_class, error_message }
          expect(described_class).to receive(:exit)
        end

        context 'Mysql2::Error with access denied error' do
          let(:exception_class) { Mysql2::Error }
          let(:error_message) { 'Access denied for user `rmt`@`localhost`' }

          it 'outputs custom error message' do
            expect { command }.to output(
              "Cannot connect to database server. Make sure it is running and configured in '/etc/rmt.conf'.\n"
            ).to_stderr
          end
        end

        context 'ActiveRecord::NoDatabaseError with access denied error' do
          let(:exception_class) { ActiveRecord::NoDatabaseError }

          it 'outputs custom error message' do
            expect { command }.to output(
              "The RMT database has not yet been initialized. Run 'systemctl start rmt-migration' to setup the database.\n"
            ).to_stderr
          end
        end

        context 'RMT::SCC::CredentialsError with access denied error' do
          let(:exception_class) { RMT::SCC::CredentialsError }

          it 'outputs custom error message' do
            expect { command }.to output(
              "The SCC credentials are not configured correctly in '/etc/rmt.conf'. You can obtain them from https://scc.suse.com/organization\n"
            ).to_stderr
          end
        end

        context 'SUSE::Connect::Api::InvalidCredentialsError with access denied error' do
          let(:exception_class) { SUSE::Connect::Api::InvalidCredentialsError }

          it 'outputs custom error message' do
            expect { command }.to output(
              "The SCC credentials are not configured correctly in '/etc/rmt.conf'. You can obtain them from https://scc.suse.com/organization\n"
            ).to_stderr
          end
        end
      end

      context 'Mysql2::Error with other error messages' do
        let(:exception_class) { Mysql2::Error }
        let(:error_message) { 'Error in SQL query' }

        before do
          expect(RMT::CLI::Mirror).to receive(:mirror) { raise exception_class, error_message }
          allow(described_class).to receive(:exit) { raise 'Called exit' }
        end

        it 'raises an exception' do
          expect { command }.to raise_exception(Mysql2::Error)
        end
      end
    end
  end
end
