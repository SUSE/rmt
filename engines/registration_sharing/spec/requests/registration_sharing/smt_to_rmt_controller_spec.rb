require 'rails_helper'

module RegistrationSharing
  RSpec.describe SmtToRmtController, type: :request do

    before do
      # registration sharing must not trigger infinite registration sharing
      expect(RegistrationSharing).not_to receive(:share)
    end

    describe '#smt_share_registration' do
      let(:product) { FactoryGirl.create(:product) }

      let(:login) { 'SCC_00000000000000000000000000000000' }
      let(:password) { 'deadbeefdeadbeefdeadbeefdeadbeef' }
      let(:regdate) { '2018-10-10 10:00:00' }
      let(:hostname) { 'example.org' }

      let(:client_xml) do
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

      let(:reg_xml) do
        "<?xml version='1.0' encoding='UTF-8'?>
        <registrationData>
          <tableData table='Registration'>
            <entry columnName='GUID' value='#{login}'/>
            <foreign_entry columnName='PRODUCTID' value='SELECT ID from Products where PRODUCTDATAID=#{product.id}'/>
            <entry columnName='REGDATE' value='#{regdate}'/>
        </tableData>
        </registrationData>"
      end

      context 'with system XML' do
        before { post '/api/regsharing/center/regsvc?command=shareregistration', params: client_xml }

        subject(:system) { System.find_by(login: login) }

        it 'creates a system' do
          expect(system).not_to eq(nil)
        end

        its(:login) { is_expected.to eq(login) }
        its(:password) { is_expected.to eq(password) }
        its(:hostname) { is_expected.to eq(hostname) }
        its(:last_seen_at) { is_expected.to eq(regdate) }
      end

      context 'with activation XML' do
        before { post '/api/regsharing/center/regsvc?command=shareregistration', params: reg_xml }

        let(:system) { System.find_by(login: login) }
        subject(:activation) { Activation.find_by(service_id: product.service.id, system_id: system.id) }

        it 'creates a system' do
          expect(activation).not_to eq(nil)
        end

        it 'creates an activation' do
          expect(activation).not_to eq(nil)
        end

        its(:created_at) { is_expected.to eq(regdate) }
      end

    end

  end
end
