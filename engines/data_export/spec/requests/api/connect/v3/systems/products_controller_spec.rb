require 'rails_helper'

describe Api::Connect::V3::Systems::ProductsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  let(:system) { FactoryBot.create(:system, :payg) }
  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions) }
  let(:payload) do
    {
      identifier: product.identifier,
      version: product.version,
      arch: product.arch,
      token: 'super_reg_code'
    }
  end

  describe '#activate' do
    subject(:activate_action) { post url, params: payload, headers: headers }

    let(:verify_plugin_double) { instance_double('InstanceVerification::Providers::Example') }
    let(:plugin_double) { instance_double('DataExport::Handlers::Example') }

    after { FileUtils.rm_rf(File.dirname(Rails.application.config.registry_cache_dir)) }

    context 'when activate success' do
      before { allow(DataExport::Handlers::Example).to receive(:new).and_return(plugin_double) }

      context 'when data export success' do
        let(:system) { FactoryBot.create(:system, :payg) }

        it do
          expect(plugin_double).to receive(:export_rmt_data)
          activate_action
        end
      end

      context 'when data export fails' do
        before do
          allow(plugin_double).to receive(:export_rmt_data).and_raise('foo')
          allow(Rails.logger).to receive(:error)
        end

        it do
          expect(plugin_double).to receive(:export_rmt_data)
          expect(Rails.logger).to receive(:error)
          activate_action
        end
      end
    end
  end
end
