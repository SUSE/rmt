require 'rails_helper'

RSpec.describe RMT::CLI::SCC do
  describe '#sync' do
    context 'without SCC credentials' do
      before do
        allow(Settings).to receive(:scc).and_return OpenStruct.new
      end

      it 'exits with an error message' do
        expect { described_class.new.sync }.to raise_error RMT::SCC::CredentialsError, 'SCC credentials not set.'
      end
    end

    context 'with an interrupt' do
      before do
        Settings.class_eval do
          def scc
          end
        end
        allow(Settings).to receive(:scc) { raise Interrupt }
      end

      it 'exits with an error message' do
        expect { described_class.new.sync }.to raise_error RMT::CLI::Error, 'Interrupted! You need to rerun this command to have a consistent state.'
      end
    end
  end
end
