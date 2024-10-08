require 'spec_helper'

describe Registry::AuthenticatedClient do
  describe '.new' do
    let(:system) { create(:system) }

    context 'with invalid cache' do
      before { allow_any_instance_of(described_class).to receive(:cache_file_exist?).and_return(false) }

      it 'raises an exception' do
        expect { described_class.new(system.login, system.password, '127.0.0.1') }.to raise_error(
          Registry::Exceptions::InvalidCredentials, /expired credentials/
          )
      end
    end

    context 'with valid cache' do
      context 'with system credentials' do
        before { allow_any_instance_of(described_class).to receive(:cache_file_exist?).and_return(true) }

        # rubocop:disable RSpec/NestedGroups
        context 'with valid credentials' do
          subject(:client) { described_class.new(system.login, system.password, '127.0.0.1') }

          it 'returns the auth strategy' do
            expect(client.systems).to eq([system])
            expect(client.account).to eq(system.login)
          end
        end

        context 'with invalid password' do
          subject(:client) { described_class.new(system.login, 'wrong', '127.0.0.1') }

          it 'raises' do
            expect { client }.to raise_error(Registry::Exceptions::InvalidCredentials)
          end
        end
        # rubocop:enable RSpec/NestedGroups
      end
    end
  end
end
