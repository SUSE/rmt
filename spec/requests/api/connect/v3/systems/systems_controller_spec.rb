require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3
  include_context 'user-agent header'
  include_context 'zypp user-agent header'
  include_context 'data profile sets'

  let(:system) { FactoryBot.create(:system, hostname: 'initial') }
  let(:url) { '/connect/systems' }
  let(:headers) { auth_header.merge(version_header) }
  let(:hwinfo) do
    {
      cpus: 16,
      sockets: 1,
      arch: 'x86_64',
      hypervisor: 'XEN',
      uuid: 'f46906c5-d87d-4e4c-894b-851e80376003',
      cloud_provider: 'testcloud'
    }
  end
  let(:payload) { { hostname: 'test', hwinfo: hwinfo } }
  let(:system_uptime) { system.system_uptimes.first }
  let(:online_hours) { ':111111111111111111111111' }
  let(:upd_online_hours) { ':111111111111111111111100' }

  describe '#update' do
    subject(:update_action) { put url, params: payload, headers: headers }

    context 'when hostname is provided' do
      it do
        expect { update_action }.to change { system.reload.hostname }.from('initial').to(payload[:hostname])
      end

      it do
        update_action

        expect(system.reload.hostname).to eq('test')
        expect(response.body).to be_empty
        expect(response.status).to eq(204)
      end

      context 'with existing hardware info' do
        it 'updates initial hardware info' do
          update_action

          information = JSON.parse(system.reload.system_information).symbolize_keys

          expect(system.reload.cloud_provider).to eq('testcloud')
          expect(information[:cpus]).to eq('16')
        end
      end

      context 'when uptime data provided' do
        let(:payload) { { hostname: 'test', hwinfo: hwinfo, online_at: [1.day.ago.to_date.to_s << online_hours] } }

        it 'inserts the uptime data in system_uptimes table' do
          update_action

          expect(system_uptime.system_id).to eq(system.reload.id)
          expect(system_uptime.online_at_day.to_date).to eq(1.day.ago.to_date)
          expect(system_uptime.online_at_hours.to_s).to eq('111111111111111111111111')
        end
      end

      context 'updates uptime data online_at_hours' do
        let(:payload) { { hostname: 'test', hwinfo: hwinfo, online_at: [1.day.ago.to_date.to_s << upd_online_hours, 1.day.ago.to_date.to_s << online_hours] } }

        it 'updates the uptime online_at_hours entry' do
          update_action
          expect(system.system_uptimes.count).to eq(1)
          expect(system_uptime.system_id).to eq(system.reload.id)
          expect(system_uptime.online_at_day.to_date).to eq(1.day.ago.to_date)
          expect(system_uptime.online_at_hours.to_s).to eq('111111111111111111111111')
        end
      end

      context 'when same uptime data duplicated' do
        let(:payload) { { hostname: 'test', hwinfo: hwinfo, online_at: [1.day.ago.to_date.to_s << online_hours, 1.day.ago.to_date.to_s << online_hours] } }

        it 'avoids duplication if multiple records have same data' do
          update_action

          expect(system.system_uptimes.count).to eq(1)
          expect(system_uptime.system_id).to eq(system.reload.id)
          expect(system_uptime.online_at_day.to_date).to eq(1.day.ago.to_date)
          expect(system_uptime.online_at_hours.to_s).to eq('111111111111111111111111')
        end
      end

      context 'when uptime data is malformed' do
        let(:payload) { { hostname: 'test', hwinfo: hwinfo, online_at: [1.day.ago.to_date.to_s] } }

        it 'record is not inserted' do
          update_action

          expect(system.system_uptimes.count).to eq(0)
        end
      end
    end

    context 'when hostname is not provided' do
      let(:payload) { { hwinfo: hwinfo } }

      it do
        update_action
        expect(system.reload.hostname).to be_nil
      end
    end

    context 'when data_profiles are provided' do
      # init with set a1
      let(:data_profiles) { data_profiles_a1 }
      let(:data_profiles_expected) { data_profiles }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      it 'they match expected set' do
        update_action

        # verify expected record linkage count between System record and SystemDataProfile records
        expect(system.system_data_profiles.count).to eq(2)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_expected)
      end
    end

    context 'when data_profiles are updated' do
      # we will be updating from set a1 to set a2
      let(:data_profiles_pre_update) { data_profiles_a1 }
      let(:data_profiles) { data_profiles_a2 }
      let(:data_profiles_expected) { data_profiles }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      before do
        # init with data_profiles_pre_update
        put url, params: payload.merge({ data_profiles: data_profiles_pre_update }), headers: headers
      end

      it 'from a1 to a2' do
        update_action

        # verify expected record linkage count between System record and SystemDataProfile records
        expect(system.system_data_profiles.count).to eq(2)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_expected)
      end
    end

    context 'when data_profiles are extended' do
      # we will be updating from set a1 to set a1 + b
      let(:data_profiles_pre_update) { data_profiles_a1 }
      let(:data_profiles) { data_profiles_pre_update.merge(data_profiles_b) }
      let(:data_profiles_expected) { data_profiles }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      before do
        # init with data_profiles_pre_update
        put url, params: payload.merge({ data_profiles: data_profiles_pre_update }), headers: headers
      end

      it 'from just set a1 to include set b' do
        update_action

        # verify expected record linkage count between System record and SystemDataProfile records
        expect(system.system_data_profiles.count).to eq(3)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_expected)
      end
    end

    context 'when data_profiles are updated with an incomplete existing set' do
      # we will be updating set a1 with incomplete set a1
      let(:data_profiles_pre_update) { data_profiles_a1 }
      let(:data_profiles) { data_profiles_a1_no_data }
      let(:data_profiles_expected) { data_profiles_pre_update }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      before do
        # init with data_profiles_pre_update
        put url, params: payload.merge({ data_profiles: data_profiles_pre_update }), headers: headers
      end

      it 'the update succeeds' do
        update_action

        # verify expected record linkage count between System record and SystemDataProfile records
        expect(system.system_data_profiles.count).to eq(2)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_expected)
      end
    end

    context 'when data_profiles are updated with an incomplete set a1 + complete set b' do
      # we will be updating from set a1 to set a1 + b
      let(:data_profiles_pre_update) { data_profiles_a1 }
      let(:data_profiles) { data_profiles_a1_no_data.merge(data_profiles_b) }
      let(:data_profiles_expected) { data_profiles_a1.merge(data_profiles_b) }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      before do
        # init with data_profiles_pre_update
        put url, params: payload.merge({ data_profiles: data_profiles_pre_update }), headers: headers
      end

      it 'they match combination of sets a1 and b' do
        update_action

        # verify expected record linkage count between System record and SystemDataProfile records
        expect(system.system_data_profiles.count).to eq(3)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_expected)
      end
    end

    context 'when a data_profiles is replaced with a different set' do
      # we will be updating from set a1 to set b
      let(:data_profiles_pre_update) { data_profiles_a1 }
      let(:data_profiles) { data_profiles_b }
      let(:data_profiles_expected) { data_profiles_b }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      before do
        # init with data_profiles_pre_update
        put url, params: payload.merge({ data_profiles: data_profiles_pre_update }), headers: headers
      end

      it 'they match the expected set' do
        update_action

        # verify expected record linkage count between System record and SystemDataProfile records
        expect(system.system_data_profiles.count).to eq(1)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_expected)
      end
    end

    context 'when data_profiles are removed' do
      # we will be updating to remove set a1
      let(:data_profiles_pre_update) { data_profiles_a1 }
      let(:data_profiles) { {} }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: {} } }

      before do
        # init with data_profiles_pre_update
        put url, params: payload.merge({ data_profiles: data_profiles_pre_update }), headers: headers
      end

      it 'no profiles are associated' do
        pending

        # before update, 2 data profiles are associated
        expect(system.system_data_profiles.count).to eq(2)

        update_action
        system.reload

        # after update, no data profiles are associated
        expect(system.system_data_profiles.count).to eq(0)
      end
    end

    context 'when data_profiles do not exist and are incomplete' do
      # we will be updating with incomplete profiles
      let(:data_profiles) { data_profiles_a1_no_data }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      it 'response header set to clear-cache and no data profiles stored' do
        update_action
        # system.reload

        expect(response.header['X-System-Profiles-Action']).to be_present
        expect(response.header['X-System-Profiles-Action']).to eq('clear-cache')
        expect(system.system_data_profiles.count).to eq(0)
      end
    end

    context 'when data_profiles are missing profileIds' do
      # we will be updating with invalid profiles
      let(:data_profiles) { data_profiles_a1_no_id }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      it 'response header set to clear-cache and no data profiles stored' do
        update_action
        # system.reload

        expect(response.header['X-System-Profiles-Action']).to be_present
        expect(response.header['X-System-Profiles-Action']).to eq('clear-cache')
        expect(system.system_data_profiles.count).to eq(0)
      end
    end

    context 'when data_profiles are mixed complete and incomplete that do not exist' do
      # we will update with incomplete set a1 and complete set b
      let(:data_profiles) { data_profiles_a1_no_data.merge(data_profiles_b) }
      let(:data_profiles_expected) { data_profiles_b }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      it 'response header set to clear-cache, only complete data profiles stored' do
        update_action

        expect(response.header['X-System-Profiles-Action']).to be_present
        expect(response.header['X-System-Profiles-Action']).to eq('clear-cache')
        expect(system.system_data_profiles.count).to eq(1)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_expected)
      end
    end

    context 'when data_profiles are mixed complete and invalid' do
      # we will update with invalid set a1 and complete set b
      let(:data_profiles) { data_profiles_a1_no_id.merge(data_profiles_b) }
      let(:data_profiles_expected) { data_profiles_b }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      it 'response header set to clear-cache, only complete data profiles stored' do
        update_action

        expect(response.header['X-System-Profiles-Action']).to be_present
        expect(response.header['X-System-Profiles-Action']).to eq('clear-cache')
        expect(system.system_data_profiles.count).to eq(1)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_expected)
      end
    end

    context 'when data_profiles are mixed incomplete and invalid' do
      # we will update with invalid set a1 and incomplete set b
      let(:data_profiles) { data_profiles_a1_no_id.merge(data_profiles_b_no_data) }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles } }

      it 'response header set to clear-cache, only complete data profiles stored' do
        update_action
        # system.reload

        expect(response.header['X-System-Profiles-Action']).to be_present
        expect(response.header['X-System-Profiles-Action']).to eq('clear-cache')
        expect(system.system_data_profiles.count).to eq(0)
      end
    end

    context 'when data_profiles are not provided' do
      let(:payload) { { hostname: 'test', hwinfo: hwinfo } }

      it 'no data profiles inserted' do
        update_action
        # system.reload

        expect(system.system_data_profiles.count).to eq(0)
      end
    end

    context 'when data_profiles upsert needs to retry' do
      # simulate the first SystemDataProfile.upsert_all() failed with a collision
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles_a1 } }

      it 'they match set a1' do
        forced_retries = 1 # force one retry
        upsert_calls = 0
        allow_any_instance_of(System).to receive(:create_profiles_if_needed).and_wrap_original do |orig_method, profiles, current_time|
          upsert_calls += 1
          if upsert_calls <= forced_retries
            raise ActiveRecord::InvalidForeignKey
          else
            orig_method.call(profiles, current_time)
          end
        end

        update_action

        expect(upsert_calls).to eq(2)

        expect(system.system_data_profiles.count).to eq(2)

        expect(
          system.system_data_profiles.each_with_object({}) do |sdp, hash|
            hash[sdp.profile_type] = {
              profileId: sdp.profile_id,
              profileData: sdp.profile_data
            }
          end.symbolize_keys
        ).to match(data_profiles_a1)
      end
    end

    context 'when data_profiles upsert retries too many times' do
      # simulate the first SystemDataProfile.upsert_all() failed with a collision
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, data_profiles: data_profiles_a1 } }

      it 'they match set a1' do
        forced_retries = 5 # set this to higher than the number of expected retries
        upsert_calls = 0
        allow_any_instance_of(System).to receive(:create_profiles_if_needed).and_wrap_original do |orig_method, profiles, current_time|
          upsert_calls += 1
          if upsert_calls <= forced_retries
            raise ActiveRecord::InvalidForeignKey
          else
            orig_method.call(profiles, current_time)
          end
        end

        expect { update_action }.to raise_error(ActiveRecord::InvalidForeignKey)

        expect(upsert_calls).to eq(4)

        expect(system.system_data_profiles.count).to eq(0)
      end
    end

    context 'stores client\'s user-agent' do
      let(:headers) { auth_header.merge(user_agent_header) }

      it 'stores suseconnect version' do
        update_action
        expect(system.reload.system_information_hash[:user_agent]).to eq('suseconnect-ng/1.2')
      end
    end

    context 'doesn\'t store zypp user-agent' do
      let(:headers) { auth_header.merge(zypp_user_agent_header) }

      it 'ignores zypp user-agent' do
        update_action
        expect(system.reload.system_information_hash[:user_agent]).to be_nil
      end
    end

    context 'response header should contain token' do
      let(:headers) { auth_header.merge('System-Token': 'existing-token') }

      it 'contains refreshed token in response' do
        update_action
        expect(response.headers).to include('System-Token')
        expect(response.headers['System-Token']).not_to equal('existing-token')
      end
    end

    context 'response header should not contain token' do
      let(:headers) { auth_header }

      it 'contains refreshed token in response' do
        update_action
        expect(response.headers).not_to include('System-Token')
      end
    end
  end

  describe '#deregister' do
    before do
      system # this will call `let()` block for :system
    end

    subject(:deregister_action) { delete url, params: payload, headers: headers }

    it 'deletes system' do
      expect { deregister_action }.to change { System.count }.by(-1)
    end
  end
end
