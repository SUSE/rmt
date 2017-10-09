require 'rails_helper'

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

    context 'handles exceptions without --debug' do
      let(:argv) { ['mirror'] }

      before do
        expect(RMT::CLI::Mirror).to receive(:mirror) { raise RMT::CLI::Error, 'Dummy exception' }
        expect(described_class).to receive(:exit)
      end

      it 'calls RMT::CLI::Mirror' do
        expect { command }.to output("Dummy exception\n").to_stderr
      end
    end

    context 'handles exceptions with --debug' do
      let(:argv) { ['mirror', '--debug'] }

      before do
        expect(RMT::CLI::Mirror).to receive(:mirror) { raise RMT::CLI::Error, 'Dummy exception' }
        expect(described_class).to receive(:exit)
      end

      it 'calls RMT::CLI::Mirror' do
        expect { command }.to output(/#<RMT::CLI::Error: Dummy exception>/).to_stderr
      end
    end
  end
end
