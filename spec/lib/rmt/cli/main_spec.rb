require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe RMT::CLI::Main, :with_fakefs do
  subject(:command) { described_class.start(argv) }

  let(:argv) { [] }

  describe '.start' do
    describe 'sync' do
      let(:argv) { ['sync'] }

      include_examples 'handles lockfile exception'

      context 'default' do
        it 'triggers sync' do
          expect_any_instance_of(RMT::SCC).to receive(:sync)
          command
        end
      end
    end

    describe 'mirror' do
      let(:argv) { ['mirror'] }

      include_examples 'handles lockfile exception'

      context 'without repositories marked for mirroring' do
        before { create :repository, :with_products, mirroring_enabled: false }

        it 'outputs a warning' do
          expect_any_instance_of(RMT::Mirror).not_to receive(:mirror)
          expect { command }.to raise_error(SystemExit).and output("There are no repositories marked for mirroring.\n").to_stderr.and output('').to_stdout
        end
      end

      context 'with repositories marked for mirroring' do
        let!(:repository) { create :repository, :with_products, mirroring_enabled: true }

        before { expect_any_instance_of(RMT::Mirror).to receive(:mirror) }

        it 'updates repository mirroring timestamp' do
          Timecop.freeze(Time.utc(2018)) do
            expect { command }.to change { repository.reload.last_mirrored_at }.to(DateTime.now.utc)
          end
        end

        context 'with exceptions during mirroring' do
          before { allow_any_instance_of(RMT::Mirror).to receive(:mirror).and_raise(RMT::Mirror::Exception, 'black mirror') }

          it 'outputs exception message' do
            expect_any_instance_of(RMT::Logger).to receive(:warn).with('black mirror')
            command
          end
        end
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

    describe 'exception handling' do
      let(:exception_class) { RMT::CLI::Error }
      let(:error_message) { 'Dummy error' }
      let(:argv) { ['sync'] }

      before do
        expect(RMT::SCC).to receive(:new).and_raise(exception_class, error_message)
        expect(described_class).to receive(:exit)
      end

      context 'without --debug' do
        it 'prints exception short message' do
          expect { command }.to output("#{error_message}\n").to_stderr
        end
      end

      context 'with --debug' do
        let(:argv) { ['sync', '--debug'] }

        it 'prints exception details' do
          expect { command }.to output(/#<RMT::CLI::Error: #{error_message}>/).to_stderr
        end
      end

      describe 'error cases' do
        describe 'RMT::Deduplicator::HardlinkException' do
          let(:exception_class) { ::RMT::Deduplicator::HardlinkException }
          let(:error_message) { 'foo' }

          it 'outputs custom error message' do
            expect { command }.to output(
              "Could not create deduplication hardlink: foo.\n"
            ).to_stderr
          end
        end
        describe 'Mysql2::Error with access denied error' do
          let(:exception_class) { Mysql2::Error }
          let(:error_message) { 'Access denied for user `rmt`@`localhost`' }

          it 'outputs custom error message' do
            expect { command }.to output(
              "Cannot connect to database server. Make sure its credentials are configured in '/etc/rmt/rmt.conf'.\n"
            ).to_stderr
          end
        end

        describe 'Mysql2::Error with cannot connect error' do
          let(:exception_class) { Mysql2::Error }
          let(:error_message) { "Can't connect to local MySQL server through socket '/var/run/mysql/mysql.sock'" }

          it 'outputs custom error message' do
            expect { command }.to output(
              "Cannot connect to database server. Make sure it is running and its credentials are configured in '/etc/rmt/rmt.conf'.\n"
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
              "The SCC credentials are not configured correctly in '/etc/rmt/rmt.conf'. You can obtain them from https://scc.suse.com/organization\n"
            ).to_stderr
          end
        end

        describe 'SUSE::Connect::Api::InvalidCredentialsError with access denied error' do
          let(:exception_class) { SUSE::Connect::Api::InvalidCredentialsError }

          it 'outputs custom error message' do
            expect { command }.to output(
              "The SCC credentials are not configured correctly in '/etc/rmt/rmt.conf'. You can obtain them from https://scc.suse.com/organization\n"
            ).to_stderr
          end
        end
      end
    end

    describe 'exceptions we do not catch' do
      before do
        expect(described_class).to receive(:help) { raise exception_class, error_message }
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
