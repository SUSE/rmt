require 'rails_helper'

module RegistrationSharing
  RSpec.describe SmtToRmtController, type: :request do
    # rubocop:disable RSpec/ExpectInHook
    before do
      # registration sharing must not trigger infinite recursive registration sharing
      expect(RegistrationSharing).not_to receive(:save_for_sharing)

      allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return(remote_ip)
      allow(Settings).to receive(:[]).with(:regsharing).and_return({ smt_allowed_ips: allowed_ips })

      post url, params: xml
    end
    # rubocop:enable RSpec/ExpectInHook

    let(:remote_ip) { '123.123.123.123' }

    describe '#regsvc' do
      context 'when IP address is not allowed' do
        subject { response }

        let(:allowed_ips) { [] }
        let(:xml) { '<xml></xml>' }
        let(:url) { '/api/regsharing/center/regsvc?command=invalidcommand' }

        its(:code) { is_expected.to eq('403') }
        its(:body) { is_expected.to eq('Forbidden') }
      end

      context 'when the command is invalid' do
        let(:allowed_ips) { [ remote_ip ] }
        let(:xml) { '<xml></xml>' }
        let(:url) { '/api/regsharing/center/regsvc?command=invalidcommand' }

        it 'returns an error' do
          expect(response.body).to eq('Command not supported')
        end
      end
    end

    describe '#smt_share_registration' do
      let(:product) { FactoryGirl.create(:product, :with_service) }
      let(:login) { 'SCC_00000000000000000000000000000000' }
      let(:password) { 'deadbeefdeadbeefdeadbeefdeadbeef' }
      let(:regdate) { '2018-10-10 10:00:00' }
      let(:hostname) { 'example.org' }
      let(:allowed_ips) { [ remote_ip ] }
      let(:url) { '/api/regsharing/center/regsvc?command=shareregistration' }

      context 'with system XML' do
        subject(:system) { System.find_by(login: login) }

        let(:xml) do
          "<?xml version='1.0' encoding='UTF-8'?>
        <registrationData>
          <tableData table='Clients'>
            <entry columnName='LASTCONTACT' value='#{regdate}'/>
            <entry columnName='HOSTNAME' value='#{hostname}'/>
            <entry columnName='GUID' value='#{login}'/>
            <entry columnName='SECRET' value='#{password}'/>
            <entry columnName='REGTYPE' value='SC'/>
            <entry columnName='TARGET' value='sle-12-x86_64'/>
          </tableData>
        </registrationData>"
        end

        it 'creates a system' do
          expect(system).not_to eq(nil)
        end

        its(:login) { is_expected.to eq(login) }
        its(:password) { is_expected.to eq(password) }
        its(:hostname) { is_expected.to eq(hostname) }
        its(:last_seen_at) { is_expected.to eq(regdate) }
      end

      context 'with activation XML' do
        subject(:activation) { Activation.find_by(service_id: product.service.id, system_id: system.id) }

        let(:xml) do
          "<?xml version='1.0' encoding='UTF-8'?>
        <registrationData>
          <tableData table='Registration'>
            <entry columnName='GUID' value='#{login}'/>
            <foreign_entry columnName='PRODUCTID' value='SELECT ID from Products where PRODUCTDATAID=#{product.id}'/>
            <entry columnName='REGDATE' value='#{regdate}'/>
        </tableData>
        </registrationData>"
        end

        let(:system) { System.find_by(login: login) }

        it 'succeeds' do
          expect(response).to have_http_status(204)
        end

        it 'creates a system' do
          expect(system).not_to eq(nil)
        end

        it 'creates an activation' do
          expect(activation).not_to eq(nil)
        end

        its(:created_at) { is_expected.to eq(regdate) }
      end

      context 'with invalid table in XML' do
        subject { response }

        let(:url) { '/api/regsharing/center/regsvc?command=shareregistration' }
        let(:xml) do
          "<?xml version='1.0' encoding='UTF-8'?>
          <registrationData>
            <tableData table='Products'>
              <entry columnName='GUID' value='#{login}'/>
              <foreign_entry columnName='PRODUCTID' value='SELECT ID from Products where PRODUCTDATAID=#{product.id}'/>
              <entry columnName='REGDATE' value='#{regdate}'/>
          </tableData>
          </registrationData>"
        end

        its(:code) { is_expected.to eq('400') }
        its(:body) { is_expected.to eq('Unknown table') }
      end
    end

    describe '#delete_registrations' do
      let!(:system) { FactoryGirl.create(:system) }
      let(:url) { '/api/regsharing/center/regsvc?command=deltesharedregistration' }
      let(:xml) do
        "<?xml version='1.0' encoding='UTF-8'?>
        <deleteRegistrationData>
          <guid>#{system.login}</guid>
        </deleteRegistrationData>"
      end
      let(:allowed_ips) { [ remote_ip ] }

      it 'removes the system' do
        expect { system.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
