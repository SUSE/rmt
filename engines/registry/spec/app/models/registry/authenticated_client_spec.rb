require 'spec_helper'

describe Registry::AuthenticatedClient do
  describe '.new' do
    context 'with system credentials' do
      let(:system) { create(:system) }

      context 'with valid credentials' do
        subject(:client) { described_class.new(system.login, system.password) }

        it 'returns the auth strategy' do
          expect(client.systems).to eq([system])
          expect(client.auth_strategy).to eq(:system_credentials)
        end
      end

      context 'with invalid password' do
        subject(:client) { described_class.new(system.login, 'wrong') }

        it 'raises' do
          expect { client }.to raise_error(Registry::Exceptions::InvalidCredentials)
        end
      end
    end

    # context 'with registration code' do
    #   let(:subscription) { create(:subscription) }

    #   context 'with valid credentials' do
    #     subject(:client) { described_class.new('any', subscription.regcode) }

    #     it 'returns the auth strategy' do
    #       expect(client.subscriptions.first).to eq(subscription)
    #       expect(client.auth_strategy).to eq(:regcode)
    #     end
    #   end

      # context 'with invalid password' do
      #   subject(:client) { described_class.new('any', 'wrong') }

      #   it 'raises' do
      #     expect { client }.to raise_error(Registry::Exceptions::InvalidCredentials)
      #   end
      # end
    # end
  end
end
