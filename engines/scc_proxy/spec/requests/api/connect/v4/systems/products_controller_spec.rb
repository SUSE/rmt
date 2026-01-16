require 'rails_helper'

describe Api::Connect::V4::Systems::ProductsController, type: :request do
  let(:url) { connect_systems_products_url }
  let(:headers) { auth_header.merge(version_header) }
  let(:instance_data) { 'dummy_instance_data' }

  describe '#deactivate' do
    context 'when system is byos' do
      include_context 'auth header', :system_byos, :login, :password
      include_context 'version header', 4
      let(:scc_systems_products_url) { 'https://scc.suse.com/connect/systems/products' }
      let(:system_byos) { FactoryBot.create(:system, :byos, :with_system_information, instance_data: instance_data) }
      let(:scc_systems_activations_url) { 'https://scc.suse.com/connect/systems/activations' }

      # rubocop:disable RSpec/NestedGroups
      context 'an activated non base module' do
        context 'with right credentials' do
          let(:product) do
            FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system_byos,
product_type: 'module')
          end
          let(:payload) do
            {
              identifier: product.identifier,
              version: product.version,
              arch: product.arch
            }
          end
          let(:serialized_service_json) do
            V3::ServiceSerializer.new(
              product.service,
              base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
              ).to_json
          end

          before do
            stub_request(:delete, scc_systems_products_url)
              .to_return(
                status: 200,
                body: '',
                headers: {}
              )
            allow(Rails.logger).to receive(:info)
            delete url, params: payload, headers: headers
          end

          it 'returns a service JSON and successfully deactivate the product' do
            expect(Rails.logger).to(
              have_received(:info).with(
                "Product '#{product.friendly_name}' successfully deactivated from SCC"
                ).once
              )
            expect(response.body).to eq(serialized_service_json)
          end
        end

        context 'when SCC API returns an error' do
          let(:product) do
            FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system_byos,
product_type: 'module')
          end
          let(:payload) do
            {
              identifier: product.identifier,
              version: product.version,
              arch: product.arch
            }
          end
          let(:serialized_service_json) do
            V3::ServiceSerializer.new(
              product.service,
              base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
              ).to_json
          end

          before do
            stub_request(:delete, scc_systems_products_url)
              .to_return(
                status: 422,
                body: "{\"error\": \"Could not de-activate product \'#{product.friendly_name}\'\"}",
                headers: {}
            )
            delete url, params: payload, headers: headers
          end

          it 'reports an error' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Could not de-activate product \'SUSE Linux Enterprise Server 15 SP3 x86_64\'')
          end
        end
      end
      # rubocop:enable RSpec/NestedGroups

      context 'an activated base module with right credentials' do
        let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system_byos) }
        let(:payload) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch
          }
        end

        before { delete url, params: payload, headers: headers }

        it 'reports an error' do
          data = JSON.parse(response.body)
          expect(data['error']).to eq("The product \"#{product.name}\" is a base product and cannot be deactivated")
        end
      end
    end

    # rubocop:disable RSpec/NestedGroups
    context 'when system is hybrid' do
      include_context 'auth header', :system_hybrid, :login, :password
      include_context 'version header', 4
      let(:scc_systems_products_url) { 'https://scc.suse.com/connect/systems/products' }
      let(:system_hybrid) { FactoryBot.create(:system, :hybrid, :with_system_information, instance_data: instance_data) }

      context 'an activated non base module' do
        context 'with right credentials' do
          let(:product) do
            FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system_hybrid,
product_type: 'module')
          end
          let(:payload) do
            {
              identifier: product.identifier,
              version: product.version,
              arch: product.arch
            }
          end
          let(:serialized_service_json) do
            V3::ServiceSerializer.new(
              product.service,
              base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
              ).to_json
          end

          before do
            stub_request(:delete, scc_systems_products_url)
              .to_return(
                status: 200,
                body: '',
                headers: {}
              )
            allow(Rails.logger).to receive(:info)
            delete url, params: payload, headers: headers
          end

          it 'returns a service JSON and successfully deactivate the product' do
            expect(Rails.logger).to(
              have_received(:info).with(
                "Product '#{product.friendly_name}' successfully deactivated from SCC"
                ).once
              )
            expect(response.body).to eq(serialized_service_json)
          end
        end

        context 'when SCC API for activations returns an error' do
          let(:product) do
            FactoryBot.create(:product, :product_sles, :extension, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system_hybrid)
          end
          let(:payload) do
            {
              identifier: product.identifier,
              version: product.version,
              arch: product.arch
            }
          end
          let(:serialized_service_json) do
            V3::ServiceSerializer.new(
              product.service,
              base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
              ).to_json
          end
          let(:scc_systems_activations_url) { 'https://scc.suse.com/connect/systems/activations' }

          before do
            stub_request(:get, scc_systems_activations_url).to_return(status: 401, body: "{\"error\": \"Error\'\"}", headers: headers)
            allow(SccProxy).to receive(:headers)
            delete url, params: payload, headers: headers
          end

          it 'reports an error' do
            data = JSON.parse(response.body)
            expect(data['error']).to eq("{\"error\": \"Error'\"}")
            expect(SccProxy).to have_received(:headers).with(headers['HTTP_AUTHORIZATION'], nil)
          end
        end

        context 'when SCC API suceeds for HYBRID system' do
          let(:product) do
            FactoryBot.create(:product, :product_sles, :extension, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system_hybrid)
          end
          let(:payload) do
            {
              identifier: product.identifier,
              version: product.version,
              arch: product.arch
            }
          end
          let(:serialized_service_json) do
            V3::ServiceSerializer.new(
              product.service,
              base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
              ).to_json
          end
          let(:scc_systems_activations_url) { 'https://scc.suse.com/connect/systems/activations' }
          let(:scc_systems_url) { 'https://scc.suse.com/connect/systems' }

          before do
            stub_request(:delete, scc_systems_products_url)
              .to_return(
                status: 200,
                body: "{\"error\": \"Could not de-activate product \'#{product.friendly_name}\'\"}",
                headers: {}
              )
            stub_request(:get, scc_systems_activations_url).to_return(status: 200, body: body_active, headers: {})
          end

          context 'when only one product was active' do
            let(:body_active) do
              [{
                id: 1,
                regcode: '631dc51f',
                name: 'Subscription 1',
                type: 'FULL',
                status: 'ACTIVE',
                starts_at: 'null',
                expires_at: DateTime.parse((Time.zone.today + 1).to_s),
                system_limit: 6,
                systems_count: 1,
                service: {
                  product: {
                    id: system_hybrid.activations.first.product.id,
                    product_class: system_hybrid.activations.first.product.product_class
                  }
                }
              }].to_json
            end

            context 'when deactivating the system succeeds' do
              before do
                stub_request(:delete, scc_systems_url).to_return(status: 204, body: '', headers: {})
                delete url, params: payload, headers: headers
              end

              it 'makes the hybrid system payg' do
                updated_system = System.find_by(login: system_hybrid.login)
                expect(updated_system.payg?).to eq(true)
              end
            end

            context 'when deactivating the system fails' do
              before do
                allow(Rails.logger).to receive(:info)
                stub_request(:delete, scc_systems_url).to_return(
                  status: 422,
                  body: '{"error": "Oh oh, something went wrong"}',
                  headers: {}
                )
                delete url, params: payload, headers: headers
              end

              it 'makes the hybrid system payg' do
                expect(Rails.logger).to(
                  have_received(:info).with(
                    "Could not de-activate system #{system_hybrid.login}, error: Oh oh, something went wrong 422"
                    ).once
                  )
                data = JSON.parse(response.body)
                expect(data['error']).to eq('Oh oh, something went wrong')
              end
            end
          end

          context 'when more activations are left' do
            let(:body_active) do
              [
                {
                  id: 1,
                  regcode: '631dc51f',
                  name: 'Subscription 1',
                  type: 'FULL',
                  status: 'ACTIVE',
                  starts_at: 'null',
                  expires_at: DateTime.parse((Time.zone.today + 1).to_s),
                  system_limit: 6,
                  systems_count: 1,
                  service: {
                    product: {
                      id: system_hybrid.activations.first.product.id,
                      product_class: system_hybrid.activations.first.product.product_class
                    }
                  }
                }, {
                  id: 2,
                  regcode: '631dc51f',
                  name: 'Subscription 1',
                  type: 'FULL',
                  status: 'ACTIVE',
                  starts_at: 'null',
                  expires_at: DateTime.parse((Time.zone.today + 1).to_s),
                  system_limit: 6,
                  systems_count: 1,
                  service: {
                    product: {
                      id: '30',
                      product_class: '23'
                    }
                  }
                }
              ].to_json
            end

            before do
              stub_request(:delete, scc_systems_url).to_return(status: 204, body: '', headers: {})
              delete url, params: payload, headers: headers
            end

            it 'keeps the system as hybrid' do
              updated_system = System.find_by(login: system_hybrid.login)
              expect(updated_system.hybrid?).to eq(true)
            end
          end
        end
      end

      context 'an activated base module with right credentials' do
        let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions, :activated, system: system_hybrid) }
        let(:payload) do
          {
            identifier: product.identifier,
            version: product.version,
            arch: product.arch
          }
        end

        before { delete url, params: payload, headers: headers }

        it 'reports an error' do
          data = JSON.parse(response.body)
          expect(data['error']).to eq("The product \"#{product.name}\" is a base product and cannot be deactivated")
        end
      end
    end
    # rubocop:enable RSpec/NestedGroups
  end
end
