require 'rails_helper'
describe Api::Connect::V3::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activate' do
    subject(:service_url) { JSON.parse(response.body)['url'] }

    let(:url) { connect_systems_products_url }
    let(:headers) { auth_header.merge(version_header) }
    let(:product) { FactoryBot.create(:product, :product_sles_sap, :with_mirrored_repositories, :with_mirrored_extensions) }

    let(:payload) do
      {
        identifier: product.identifier.downcase,
        version: product.version,
        arch: product.arch,
        byos_mode: 'byos'
      }
    end

    before do
      allow(InstanceVerification).to receive(:update_cache)
      allow(File).to receive(:directory?)
      allow(Dir).to receive(:mkdir)
      allow(FileUtils).to receive(:touch)
      post url, headers: headers, params: payload
    end

    context 'when system is registered with the old client' do
      let(:system) { FactoryBot.create(:system, :with_system_information, instance_data: '<document>test</document>') }

      it 'service url has http scheme' do
        expect(service_url).to match(%r{^plugin:/susecloud})
        # when no token in params we do not update the pubcloud registration code
        # bsc#1244166
        expect(controller).not_to receive(:update_pubcloud_reg_code)
      end
    end

    context 'when system is registered with the new client' do
      let(:system) do
        FactoryBot.create(
          :system, :with_system_information,
          instance_data: '<document>test</document><repoformat>plugin:susecloud</repoformat>'
        )
      end

      it 'service url has plugin:susecloud scheme' do
        expect(service_url).to match(%r{^plugin:/susecloud})
      end
    end
  end
end
