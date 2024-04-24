require 'rails_helper'

describe SUSE::Connect::SystemSerializer do
  subject(:serializer) { described_class.new(system).to_h }

  let(:system) { create :system, :full }

  context 'not synchronized system' do
    let(:hwinfo_parameters) { JSON.parse(system.system_information).symbolize_keys }
    let(:activation) { system.activations.first }
    let(:product) { activation.product }

    let(:expected) do
      {
        login: system.login,
        password: system.password,
        last_seen_at: system.last_seen_at,
        created_at: system.created_at,
        hostname: system.hostname,
        hwinfo: hwinfo_parameters,
        products: [
          {
            id: product.id,
            identifier: product.identifier,
            version: product.version,
            arch: product.arch,
            activated_at: activation.created_at
          }
        ]
      }
    end

    it { is_expected.to match(expected) }
  end

  context 'synchronized system' do
    let(:system) { create :system, :full, :synced }
    let(:expected) do
      {
        login: system.login,
        password: system.password,
        last_seen_at: system.last_seen_at,
        created_at: system.created_at
      }
    end

    it { is_expected.to match(expected) }
  end

  context 'system with system_token' do
    let(:system) { create :system, :full, :synced, :with_system_token }
    let(:expected) do
      {
        login: system.login,
        password: system.password,
        last_seen_at: system.last_seen_at,
        created_at: system.created_at,
        system_token: system.id
      }
    end

    it { is_expected.to match(expected) }
  end

  context 'system with activation and subscriptions' do
    let(:subscription) { create :subscription }
    let(:system) { create :system, :full, subscription: subscription }

    it 'does add the subscriptions regcode if associated' do
      expect(serializer[:products][0][:regcode]).to eq(subscription.regcode)
    end
  end

  context 'system without hardware info' do
    let(:system) { create :system, :synced }

    it 'does not add the hwinfo attribute' do
      expect(serializer.key? :hwinfo).to eq(false)
    end
  end

  context 'system without system_token' do
    let(:system) { create :system, :synced, system_token: nil }

    it 'does not add the system_token attribute' do
      expect(serializer.key? :system_token).to eq(false)
    end
  end

  context 'system with systemuptime' do
    let(:system) { create :system, :with_system_uptimes }

    it 'match systemuptime data' do
      expect((serializer[:online_at][0][:online_at_day]).to_date).to eq(Time.zone.now.to_date)
      expect((serializer[:online_at][0][:online_at_hours]).to_s).to eq('111111111111111111111111')
    end
  end
end
