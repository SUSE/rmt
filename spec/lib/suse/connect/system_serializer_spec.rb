require 'rails_helper'

describe SUSE::Connect::SystemSerializer do
  subject(:serializer) { described_class.new(system, serializer_options).to_h }

  let(:system) { create :system, :full }
  let(:serializer_options) { { serialized_profiles: Set.new } }
  let(:profiles) do
    system.profiles.each_with_object({}) do |profile, hash|
      hash[profile.profile_type] = {
        identifier: profile.identifier,
        data: profile.data
      }
    end
  end

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
        system_profiles: profiles,
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
        created_at: system.created_at,
        system_profiles: profiles
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
        system_profiles: profiles,
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

  context 'system without profiles' do
    let(:system) { create :system, :synced }

    it 'does not add the system_profiles attribute' do
      expect(serializer.key?(:system_profiles)).to eq(false)
    end
  end

  context 'system with profiles' do
    let(:system) { create :system, :with_profiles }

    it 'does add the system_profiles attribute' do
      expect(serializer.key?(:system_profiles)).to eq(true)
    end

    it 'matches system_profiles attribute' do
      expect(serializer[:system_profiles]).to match(profiles)
    end
  end

  context 'system with profiles already serialized' do
    # Create system, init a serialized_profiles with it's associated
    # profile_ids, define an expected profiles without the data field
    let(:system) { create :system, :with_profiles }
    let(:serializer_options) { { serialized_profiles: Set.new.merge(system.profile_ids) } }
    let(:profiles) do
      system.profiles.each_with_object({}) do |profile, hash|
        hash[profile.profile_type] = {
          identifier: profile.identifier
        }
      end
    end

    it 'does add the system_profiles attribute' do
      expect(serializer.key?(:system_profiles)).to eq(true)
    end

    it 'matches expected previously serialised system_profiles attribute' do
      expect(serializer[:system_profiles]).to match(profiles)
    end
  end
end
