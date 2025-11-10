require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3
  include_context 'user-agent header'
  include_context 'zypp user-agent header'
  include_context 'profile sets'

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

    context 'when profiles are provided' do
      # init with profile set all
      let(:profiles) { profile_set_all }
      let(:profiles_expected) { profiles }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      it 'they are expected to match set a1' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).not_to be_present

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are updated' do
      # update from set a1 to set a2
      let(:profiles_pre_update) { profile_set_a1 }
      let(:profiles) { profile_set_a2 }
      let(:profiles_expected) { profiles }
      let(:payload_pre_update) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles_pre_update } }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      before do
        put url, params: payload_pre_update, headers: headers
      end

      it 'from set a1 to set a2' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).not_to be_present

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are replaced' do
      # replace set b with set c
      let(:profiles_pre_update) { profile_set_b }
      let(:profiles) { profile_set_c }
      let(:profiles_expected) { profiles }
      let(:payload_pre_update) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles_pre_update } }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      before do
        put url, params: payload_pre_update, headers: headers
      end

      it 'changing from set b to set c' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).not_to be_present

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are extended' do
      # replace set b with set c
      let(:profiles_pre_update) { profile_set_b }
      let(:profiles) { profile_set_b.merge(profile_set_c) }
      let(:profiles_expected) { profiles }
      let(:payload_pre_update) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles_pre_update } }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      before do
        put url, params: payload_pre_update, headers: headers
      end

      it 'adding set c to set b' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).not_to be_present

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are invalid' do
      # update with invalid set a1
      let(:profiles_pre_update) { {} }
      let(:profiles) { profile_set_a1_no_ident }
      let(:profiles_expected) { profiles_pre_update }
      let(:payload_pre_update) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles_pre_update } }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      before do
        put url, params: payload_pre_update, headers: headers
      end

      it 'existing profile is matched' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).to be_present
        expect(response.headers['X-System-Profiles-Action']).to eq('clear-cache')

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are incomplete and not previously reported' do
      # update with incomplete set a1 that doesn't already exist
      let(:profiles_pre_update) { {} }
      let(:profiles) { profile_set_a1_no_data }
      let(:profiles_expected) { profiles_pre_update }
      let(:payload_pre_update) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles_pre_update } }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      before do
        put url, params: payload_pre_update, headers: headers
      end

      it 'existing profile is matched' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).to be_present
        expect(response.headers['X-System-Profiles-Action']).to eq('clear-cache')

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are incomplete but previously reported' do
      # update with incomplete set a1 that already exists
      let(:profiles_pre_update) { profile_set_a1 }
      let(:profiles) { profile_set_a1_no_data }
      let(:profiles_expected) { profiles_pre_update }
      let(:payload_pre_update) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles_pre_update } }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      before do
        put url, params: payload_pre_update, headers: headers
      end

      it 'existing profile is matched' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).not_to be_present

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are mixed and none previously exist' do
      # update with incomplete set a1 that already exists
      let(:profiles_pre_update) { {} }
      let(:profiles) { profile_set_mixed }
      let(:profiles_expected) { profile_set_mixed_complete }
      let(:payload_pre_update) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles_pre_update } }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      before do
        put url, params: payload_pre_update, headers: headers
      end

      it 'only complete profiles stored and clear-cache header set' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).to be_present
        expect(response.headers['X-System-Profiles-Action']).to eq('clear-cache')

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are mixed and incompletes previously exist' do
      # update with incomplete set a1 that already exists
      let(:profiles_pre_update) { profile_set_mixed_incomplete_full }
      let(:profiles) { profile_set_mixed }
      let(:profiles_expected) { profile_set_mixed_valid }
      let(:payload_pre_update) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles_pre_update } }
      let(:payload) { { hostname: 'test', hwinfo: hwinfo, system_profiles: profiles } }

      before do
        put url, params: payload_pre_update, headers: headers
      end

      it 'only valid profiles stored and clear-cache header set' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).to be_present
        expect(response.headers['X-System-Profiles-Action']).to eq('clear-cache')

        expect(
          system.profiles.each_with_object({}) do |profile, hash|
            hash[profile.profile_type] = {
              identifier: profile.identifier,
              data: profile.data
            }
          end.symbolize_keys
        ).to match(profiles_expected)
      end
    end

    context 'when profiles are not provided' do
      let(:payload) { { hostname: 'test', hwinfo: hwinfo } }

      it 'no profiles are associated with system' do
        update_action

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
        expect(response.headers['X-System-Profiles-Action']).not_to be_present

        expect(system.profiles.count).to eq(0)
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
