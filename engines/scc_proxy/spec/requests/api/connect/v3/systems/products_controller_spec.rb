require 'base64'
require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

describe Api::Connect::V3::Systems::ProductsController, type: :request do
  let(:url) { connect_systems_products_url }
  let(:product_sap) { FactoryBot.create(:product, :product_sles_sap, :with_mirrored_repositories, :with_mirrored_extensions) }
  let(:instance_data) { '<instance_data/>' }
  let(:scc_register_system_url) { 'https://scc.suse.com/connect/subscriptions/systems' }
  let(:scc_activate_url) { 'https://scc.suse.com/connect/systems/products' }
  let(:scc_systems_url) { 'https://scc.suse.com/connect/systems' }

  describe '#activate' do
    let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }


    context 'when system is BYOS' do
      include_context 'auth header', :system_byos, :login, :password
      include_context 'version header', 3
      let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions) }
      let(:headers) { auth_header.merge(version_header) }
      let(:payload_byos) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch,
          email: 'foo',
          token: 'bar',
          byos_mode: 'byos',
          hwinfo:
          {
            hostname: 'test',
            cpus: '1',
            sockets: '1',
            hypervisor: 'Xen',
            arch: 'x86_64',
            uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
            cloud_provider: 'amazon'
          }
        }
      end

      context 'when system has hw_info' do
        let(:instance_data) { '<document>{"instanceId": "dummy_instance_data"}</document>' }
        let(:new_system_token) { 'BBBBBBBB-BBBB-4BBB-9BBB-BBBBBBBBBBBB' }
        let(:system_byos) { FactoryBot.create(:system, :byos, :with_system_information, instance_data: instance_data) }
        let(:serialized_service_json) do
          V3::ServiceSerializer.new(
            product.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        let(:serialized_service_sap_json) do
          V3::ServiceSerializer.new(
            product_sap.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        context 'when system is connected to SCC' do
          let(:system_byos) do
            FactoryBot.create(:system, :byos, :with_system_information, instance_data: instance_data,
              system_token: new_system_token)
          end
          let(:subscription_response) do
            {
              id: 4206714,
              regcode: 'bar',
              name: 'SUSE Employee subscription for SUSE Linux Enterprise Server for SAP Applications',
              type: 'internal',
              status: 'ACTIVE',
              starts_at: '2019-03-20T09:48:52.658Z',
              expires_at: '2024-03-20T09:48:52.658Z',
              system_limit: '100',
              systems_count: '156',
              virtual_count: nil,
              product_classes: [
                'AiO',
                '7261',
                'SLE-HAE-X86',
                '7261-BETA',
                'SLE-HAE-X86-BETA',
                'AiO-BETA',
                '7261-ALPHA',
                'SLE-HAE-X86-ALPHA',
                'AiO-ALPHA'
              ],
              product_ids: [
                1959,
                1421
              ],
              skus: [],
              systems: [
                {
                  id: 3021957,
                  login: 'SCC_foo',
                  password: '5ee7273ac6ac4d7f',
                  last_seen_at: '2019-03-20T14:01:05.424Z'
                }
              ]
            }
          end
          let(:headers) { auth_header.merge('X-Instance-Data' => Base64.strict_encode64('dummy_instance_data')) }

          before do
            allow(plugin_double).to(
              receive(:instance_valid?)
                .and_raise(InstanceVerification::Exception, 'Custom plugin error')
            )
            allow(plugin_double).to receive(:instance_identifier).and_return('foo')
          end

          context 'with a valid registration code' do
            before do
              stub_request(:post, scc_activate_url)
                .to_return(
                  status: 201,
                  body: { id: 'bar' }.to_json,
                  headers: {}
                )
              allow(File).to receive(:directory?)
              allow(FileUtils).to receive(:mkdir_p)
              allow(FileUtils).to receive(:touch)
              allow_any_instance_of(InstanceVerification::Providers::Example).to receive(:instance_identifier).and_return('foo')
              allow(InstanceVerification).to receive(:write_cache_file).with(
                Rails.application.config.repo_byos_cache_dir,
                "#{Base64.strict_encode64(payload_byos[:token])}-foo-#{product.product_class}-active"
              )
              allow(InstanceVerification).to receive(:write_cache_file).with(
                Rails.application.config.registry_cache_dir,
                "#{Base64.strict_encode64(payload_byos[:token])}-foo-#{product.product_class}-active"
              )
            end

            it 'renders service JSON' do
              system_byos.update!(system_token: nil)
              post url, params: payload_byos, headers: headers
              # Compare parsed JSON to avoid encoding issues (UTF-8 vs ASCII-8BIT)
              expect(response.parsed_body).to eq(JSON.parse(serialized_service_json))
            end
          end

          context 'with a not valid registration code' do
            before do
              stub_request(:post, scc_activate_url)
                .to_return(
                  status: 401,
                  body: { error: 'No product found on SCC for: foo bar x86_64 json api' }.to_json,
                  headers: {}
                )
              allow(InstanceVerification).to receive(:write_cache_file)
              allow(FileUtils).to receive(:mkdir_p)
              allow(FileUtils).to receive(:touch)

              post url, params: payload_byos, headers: headers
            end

            it 'renders an error with exception details' do
              data = response.parsed_body
              expect(data['error']).to include('No product found on SCC')
              expect(data['error']).not_to include('json api')
            end
          end

          context 'with different system_tokens' do
            let(:system_byos2) do
              FactoryBot.create(:system, :byos, :with_system_information, instance_data: instance_data,
                system_token: 'foo')
            end

            before do
              allow(System).to receive(:get_by_credentials).and_return([system_byos, system_byos2])
              allow(plugin_double).to(
                receive(:instance_valid?)
                  .and_raise(InstanceVerification::Exception, 'Custom plugin error')
              )
              stub_request(:post, scc_activate_url)
                .to_return(
                  status: 201,
                  body: { id: 'bar' }.to_json,
                  headers: {}
                )
              allow(InstanceVerification).to receive(:write_cache_file)
              allow(File).to receive(:directory?)
              allow(FileUtils).to receive(:mkdir_p)
              allow(FileUtils).to receive(:touch)

              post url, params: payload_byos, headers: headers
            end

            it 'renders service JSON' do
              # Compare parsed JSON to avoid encoding issues (UTF-8 vs ASCII-8BIT)
              expect(response.parsed_body).to eq(JSON.parse(serialized_service_json))
            end
          end

          context 'with duplicated system_tokens' do
            let(:system_byos3) do
              FactoryBot.create(:system, :byos, :with_system_information, instance_data: instance_data,
                system_token: 'foo')
            end

            before do
              system_byos3 = system_byos
              system_byos3.save!
              allow(System).to receive(:get_by_credentials).and_return([system_byos, system_byos3])
              allow(plugin_double).to(
                receive(:instance_valid?)
                  .and_raise(InstanceVerification::Exception, 'Custom plugin error')
              )
              headers['System-Token'] = 'foo'
              stub_request(:post, scc_activate_url)
                .to_return(
                  status: 201,
                  body: { id: 'bar' }.to_json,
                  headers: {}
                )

              allow(InstanceVerification).to receive(:write_cache_file)
              allow(File).to receive(:directory?)
              allow(FileUtils).to receive(:mkdir_p)
              allow(FileUtils).to receive(:touch)

              post url, params: payload_byos, headers: headers
            end

            it 'renders service JSON' do
              # Compare parsed JSON to avoid encoding issues (UTF-8 vs ASCII-8BIT)
              expect(response.parsed_body).to eq(JSON.parse(serialized_service_json))
            end
          end
        end
      end
    end

    context 'when activating extensions for BYOS' do
      let(:instance_data) { 'dummy_instance_data' }
      let(:system_byos) do
        FactoryBot.create(
          :system, :byos, :with_system_information, :with_activated_product, product: base_product, instance_data: instance_data
        )
      end
      let(:serialized_service_json) do
        V3::ServiceSerializer.new(
          product.service,
          base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
        ).to_json
      end
      let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }
      let(:payload_byos) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch,
          email: 'foo',
          token: 'bar',
          byos_mode: 'byos',
          hwinfo:
          {
            hostname: 'test',
            cpus: '1',
            sockets: '1',
            hypervisor: 'Xen',
            arch: 'x86_64',
            uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
            cloud_provider: 'amazon'
          }
        }
      end

      before do
        allow(InstanceVerification::Providers::Example).to receive(:new)
          .with(nil, nil, nil, 'dummy_instance_data').and_return(plugin_double)
        allow(plugin_double).to receive(:parse_instance_data).and_return({ InstanceId: 'foo' })
        FactoryBot.create(:subscription, product_classes: product_classes)
        stub_request(:post, scc_activate_url)
          .to_return(
            status: 401,
            body: { error: 'Instance verification failed: The product is not available for this instance' }.to_json,
            headers: {}
          )
        # stub the fake announcement call PAYG has to do to SCC
        # to create the system before activate product (and skip validation)
        stub_request(:post, scc_register_system_url)
          .to_return(status: 201, body: { ok: 'OK' }.to_json, headers: {})

        post url, params: payload_byos, headers: headers
      end
    end

    context 'when system is PAYG' do
      include_context 'auth header', :system_payg, :login, :password
      include_context 'version header', 3
      let(:headers) { auth_header.merge(version_header) }
      let(:system_payg) { FactoryBot.create(:system, :payg, :with_system_information, :with_activated_base_product, instance_data: instance_data) }
      let(:product) do
        FactoryBot.create(
          :product, :product_sles, :extension, :with_mirrored_repositories, :with_mirrored_extensions,
          base_products: [system_payg.products.first]
          )
      end
      let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }
      let(:payload) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch,
          instance_data: instance_data,
          token: 'bar',
          byos_mode: 'hybrid',
          hwinfo:
          {
            hostname: 'super_test',
            cpus: '1',
            sockets: '1',
            hypervisor: 'Xen',
            arch: 'x86_64',
            uuid: 'ec235f7d-b435-e27d-86c6-c8fef3180a01',
            cloud_provider: 'amazon'
          }
        }
      end

      context 'when system has hw_info' do
        let(:instance_data) { '<document>{"instanceId": "dummy_instance_data"}</document>' }
        let(:new_system_token) { 'BBBBBBBB-BBBB-4BBB-9BBB-BBBBBBBBBBBB' }
        let(:serialized_service_json) do
          V3::ServiceSerializer.new(
            product.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        let(:serialized_service_sap_json) do
          V3::ServiceSerializer.new(
            product_sap.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        context 'when system is connected to SCC' do
          let(:system_payg) do
            FactoryBot.create(:system, :payg, :with_system_information, :with_activated_base_product, instance_data: instance_data,
              system_token: new_system_token)
          end
          let(:product) do
            FactoryBot.create(
              :product, :product_sles_ltss, :extension, :with_mirrored_repositories, :with_mirrored_extensions,
              base_products: [system_payg.products.first]
              )
          end
          let(:subscription_response) do
            {
              id: 4206714,
              regcode: 'bar',
              name: 'SUSE Employee subscription for SUSE Linux Enterprise Server for SAP Applications',
              type: 'internal',
              status: 'ACTIVE',
              starts_at: '2019-03-20T09:48:52.658Z',
              expires_at: '2024-03-20T09:48:52.658Z',
              system_limit: '100',
              systems_count: '156',
              virtual_count: nil,
              product_classes: [
                'AiO',
                '7261',
                'SLE-HAE-X86',
                '7261-BETA',
                'SLE-HAE-X86-BETA',
                'AiO-BETA',
                '7261-ALPHA',
                'SLE-HAE-X86-ALPHA',
                'AiO-ALPHA'
              ],
              product_ids: [
                1959,
                1421
              ],
              skus: [],
              systems: [
                {
                  id: 3021957,
                  login: 'SCC_foo',
                  password: '5ee7273ac6ac4d7f',
                  last_seen_at: '2019-03-20T14:01:05.424Z'
                }
              ]
            }
          end

          before do
            allow(plugin_double).to(
              receive(:instance_valid?)
                .and_raise(InstanceVerification::Exception, 'Custom plugin error')
            )
          end

          context 'with a valid registration code' do
            before do
              stub_request(:post, scc_activate_url)
                .to_return(
                  status: 201,
                  body: { id: 'bar' }.to_json,
                  headers: {}
                )
              allow(File).to receive(:directory?)
              allow(FileUtils).to receive(:mkdir_p)
              allow(FileUtils).to receive(:touch)
              allow(InstanceVerification::Providers::Example).to receive(:new).and_return(plugin_double)
              allow(plugin_double).to receive(:allowed_extension?).and_return(true)
              allow(InstanceVerification).to receive(:write_cache_file)
              allow(plugin_double).to receive(:instance_valid?).and_return(true)
            end

            context 'when LTSS not allowed' do
              before do
                allow(plugin_double).to receive(:allowed_extension?).and_return(false)
              end

              it 'raises an error' do
                stub_request(:post, scc_register_system_url)
                  .to_return(status: 403, body: { ok: 'OK' }.to_json, headers: {})

                post url, params: payload, headers: headers
                data = response.parsed_body
                expect(data['error']).to include('Product not supported for this instance')
              end
            end
          end
        end
      end

      context 'when system has hw info' do
        let(:instance_data) { '<document>{"instanceId": "dummy_instance_data"}</document>' }
        let(:new_system_token) { 'BBBBBBBB-BBBB-4BBB-9BBB-BBBBBBBBBBBB' }
        let(:serialized_service_json) do
          V3::ServiceSerializer.new(
            product.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        let(:serialized_service_sap_json) do
          V3::ServiceSerializer.new(
            product_sap.service,
            base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host }).to_s
          ).to_json
        end

        context 'when system is connected to SCC' do
          let(:system_payg) do
            FactoryBot.create(:system, :payg, :with_system_information, :with_activated_base_product, :with_profiles, instance_data: instance_data,
              system_token: new_system_token)
          end
          let(:product) do
            FactoryBot.create(
              :product, :product_sles_ltss, :extension, :with_mirrored_repositories, :with_mirrored_extensions,
              base_products: [system_payg.products.first]
              )
          end
          let(:subscription_response) do
            {
              id: 4206714,
              regcode: 'bar',
              name: 'SUSE Employee subscription for SUSE Linux Enterprise Server for SAP Applications',
              type: 'internal',
              status: 'ACTIVE',
              starts_at: '2019-03-20T09:48:52.658Z',
              expires_at: '2024-03-20T09:48:52.658Z',
              system_limit: '100',
              systems_count: '156',
              virtual_count: nil,
              product_classes: [
                'AiO',
                '7261',
                'SLE-HAE-X86',
                '7261-BETA',
                'SLE-HAE-X86-BETA',
                'AiO-BETA',
                '7261-ALPHA',
                'SLE-HAE-X86-ALPHA',
                'AiO-ALPHA'
              ],
              product_ids: [
                1959,
                1421
              ],
              skus: [],
              systems: [
                {
                  id: 3021957,
                  login: 'SCC_foo',
                  password: '5ee7273ac6ac4d7f',
                  last_seen_at: '2019-03-20T14:01:05.424Z'
                }
              ]
            }
          end

          context 'with a valid registration code' do
            before do
              stub_request(:post, scc_activate_url)
                .to_return(
                  status: 201,
                  body: { id: 'bar' }.to_json,
                  headers: {}
                )
              allow(File).to receive(:directory?)
              allow(FileUtils).to receive(:mkdir_p)
              allow(FileUtils).to receive(:touch)
              allow(InstanceVerification).to receive(:reg_code_in_cache?).and_return('')
              allow(InstanceVerification).to receive(:write_cache_file)
              allow(plugin_double).to receive(:instance_valid?).and_return(true)
            end

            it 'renders service JSON' do
              stub_request(:post, scc_register_system_url)
                .to_return(status: 201, body: { ok: 'OK' }.to_json, headers: {})

              post url, params: payload, headers: headers
              # Compare parsed JSON to avoid encoding issues (UTF-8 vs ASCII-8BIT)
              expect(response.parsed_body).to eq(JSON.parse(serialized_service_json))
            end

            context 'instance verification error' do
              let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

              it 'returns error' do
                expect(InstanceVerification::Providers::Example).to receive(:new).at_least(:once).and_return(plugin_double)
                allow(plugin_double).to receive(:allowed_extension?).and_raise(InstanceVerification::Exception, 'Malformed instance data')
                post url, params: payload, headers: headers
                expect(response.parsed_body['error']).to eq('Malformed instance data')
                expect(response.message).to eq('Unprocessable Content')
                expect(response.code).to eq('422')
              end
            end
          end

          context 'with a not valid registration code' do
            let(:scc_register_systems_url) { 'https://scc.suse.com/connect/subscriptions/systems' }

            context 'with JSON in the response' do
              before do
                stub_request(:post, scc_register_systems_url)
                  .to_return(
                    status: [422, 'Bad Request'],
                    body: { type: 'error', error: 'Oh oh, something went wrong' }.to_json,
                    headers: {}
                  )
              end

              it 'renders the error' do
                post url, params: payload, headers: headers
                data = response.parsed_body
                expect(data['error']).to include('went wrong')
              end
            end

            context 'no JSON in the response' do
              before do
                stub_request(:post, scc_register_systems_url)
                  .to_return(
                    status: [422, 'Bad Request'],
                    body: 'not a json',
                    headers: {}
                  )
              end

              it 'renders the error' do
                post url, params: payload, headers: headers
                data = response.parsed_body
                expect(data['error']).to include('Bad Request')
              end
            end
          end
        end
      end
    end

    context 'when the first product activation fails' do
      include_context 'version header', 3

      let(:instance_data) { '<document>{"instanceId": "dummy_instance_data"}</document>' }
      let(:product) { FactoryBot.create(:product, :product_sles, :with_mirrored_repositories, :with_mirrored_extensions) }
      let(:activation_payload) do
        {
          identifier: product.identifier,
          version: product.version,
          arch: product.arch,
          email: 'foo',
          token: 'bar'
        }
      end

      before do
        allow(InstanceVerification).to receive(:write_cache_file)
        allow(File).to receive(:directory?)
        allow(FileUtils).to receive(:mkdir_p)
        allow(FileUtils).to receive(:touch)
      end

      context 'when the system is byos' do
        include_context 'auth header', :system_byos, :login, :password

        let(:headers) { auth_header.merge(version_header) }
        let(:system_byos) do
          FactoryBot.create(:system, :byos, :with_system_information, instance_data: instance_data, system_token: 'foo')
        end

        before do
          stub_request(:post, scc_activate_url)
            .to_return(
              status: 401,
              body: { error: 'No product found on SCC for: foo bar x86_64' }.to_json,
              headers: {}
            )
        end

        context 'when the system was not announced to SCC by this RMT' do
          it 'removes the announced but unregistered system' do
            system_byos
            expect { post url, params: activation_payload, headers: headers }.to change(System, :count).by(-1)
          end

          it 'does not de-register the system from SCC' do
            post url, params: activation_payload, headers: headers
            expect(WebMock).not_to have_requested(:delete, scc_systems_url)
          end

          it 'renders an error with exception details' do
            post url, params: activation_payload, headers: headers
            expect(response.parsed_body['error']).to include('No product found on SCC')
          end
        end

        context 'when the system was announced to SCC by this RMT' do
          let(:system_byos) do
            FactoryBot.create(
              :system, :byos, :synced, :with_system_information, instance_data: instance_data, system_token: 'foo'
            )
          end

          before do
            stub_request(:delete, scc_systems_url).to_return(status: 204, body: '', headers: {})
          end

          it 'de-registers the system from SCC' do
            post url, params: activation_payload, headers: headers
            expect(WebMock).to have_requested(:delete, scc_systems_url)
          end

          it 'removes the announced but unregistered system' do
            system_byos
            expect { post url, params: activation_payload, headers: headers }.to change(System, :count).by(-1)
          end
        end

        context 'when de-registering the system from SCC fails' do
          let(:system_byos) do
            FactoryBot.create(
              :system, :byos, :synced, :with_system_information, instance_data: instance_data, system_token: 'foo'
            )
          end

          before do
            stub_request(:delete, scc_systems_url)
              .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json, headers: {})
          end

          it 'removes the system anyway' do
            system_byos
            expect { post url, params: activation_payload, headers: headers }.to change(System, :count).by(-1)
          end

          it 'reports the original activation error' do
            post url, params: activation_payload, headers: headers
            expect(response.parsed_body['error']).to include('No product found on SCC')
          end
        end

        context 'when the system already has an activation' do
          let(:system_byos) do
            FactoryBot.create(
              :system, :byos, :synced, :with_system_information, :with_activated_product,
              instance_data: instance_data, system_token: 'foo'
            )
          end

          it 'keeps the system' do
            system_byos
            expect { post url, params: activation_payload, headers: headers }.not_to change(System, :count)
          end

          it 'does not de-register the system from SCC' do
            post url, params: activation_payload, headers: headers
            expect(WebMock).not_to have_requested(:delete, scc_systems_url)
          end
        end
      end

      context 'when the product is not supported for the instance' do
        before do
          allow(InstanceVerification::Providers::Example).to receive(:new).and_return(plugin_double)
          allow(plugin_double).to receive(:instance_valid?).and_return(true)
          allow(plugin_double).to receive(:instance_identifier).and_return('foo')
          allow(plugin_double).to receive(:allowed_extension?).and_return(false)
        end

        context 'when the system is byos' do
          include_context 'auth header', :system_byos, :login, :password

          let(:headers) { auth_header.merge(version_header) }
          let(:system_byos) do
            FactoryBot.create(:system, :byos, :with_system_information, instance_data: instance_data, system_token: 'foo')
          end

          it 'removes the announced but unregistered system' do
            system_byos
            expect { post url, params: activation_payload, headers: headers }.to change(System, :count).by(-1)
          end
        end

        context 'when the system is payg' do
          include_context 'auth header', :system_payg, :login, :password

          let(:headers) { auth_header.merge(version_header) }
          let(:system_payg) do
            FactoryBot.create(:system, :payg, :with_system_information, instance_data: instance_data)
          end

          it 'keeps the system, only byos announcements are dropped here' do
            system_payg
            expect { post url, params: activation_payload, headers: headers }.not_to change(System, :count)
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
