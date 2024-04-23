require 'spec_helper'

describe Registry::AuthenticatedClient do
  describe '.new' do
    context 'with system credentials' do
      let(:system) { create(:system) }

      context 'with valid credentials' do
        subject(:client) { described_class.new(system.login, system.password, '23.23.23.23') }

        it 'returns the auth strategy' do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:ctime).and_return(Time.zone.now)
          expect(client.systems).to eq([system])
          expect(client.auth_strategy).to eq(:system_credentials)
        end
      end

      context 'with invalid password' do
        subject(:client) { described_class.new(system.login, 'wrong', '23.23.23.23') }

        it 'raises' do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:ctime).and_return(Time.zone.now)
          allow(File).to receive(:delete)
          expect { client }.to raise_error(Registry::Exceptions::InvalidCredentials)
        end
      end
    end

    context 'with system not seen recently' do
      let(:system) { create(:system, last_seen_at: Settings[:registry].token_expiration.seconds.ago) }

      context 'even with valid credentials' do
        subject(:client) { described_class.new(system.login, system.password, '23.23.23.23') }

        it 'raises' do
          allow(File).to receive(:delete)
          expect { client }.to raise_error(Registry::Exceptions::InvalidCredentials)
        end
      end
    end
  end
end
