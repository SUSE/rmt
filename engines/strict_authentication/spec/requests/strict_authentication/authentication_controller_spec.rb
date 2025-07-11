require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module StrictAuthentication
  RSpec.describe AuthenticationController, type: :request do
    subject { response }

    let(:system) { FactoryBot.create(:system, :payg, :with_activated_product_sle_micro) }

    describe '#check' do
      context 'without authentication' do
        before { get '/api/auth/check' }
        its(:code) { is_expected.to eq '401' }
      end

      context 'with invalid credentials' do
        before { get '/api/auth/check', headers: basic_auth_header('invalid', 'invalid') }
        its(:code) { is_expected.to eq '401' }
      end

      context 'with valid credentials' do
        include_context 'auth header', :system, :login, :password

        context 'valid instance' do
          before do
            allow(InstanceVerification).to receive(:verify_instance).and_return(true)
            get '/api/auth/check', headers: auth_header.merge({ 'X-Original-URI': requested_uri, 'X-Instance-Data': Base64.strict_encode64('IMDS') })
            allow(File).to receive(:directory?)
            allow(Dir).to receive(:mkdir)
            allow(FileUtils).to receive(:touch)
          end

          context 'when requested path is not activated' do
            let(:requested_uri) { '/repo/some/uri' }

            its(:code) { is_expected.to eq '403' }
          end

          context 'when requesting a file in an activated SLES repo on a SLE Micro system' do
            let(:free_product) do
              prod = FactoryBot.create(
                :product, :module, :with_mirrored_repositories
                )
              prod.identifier = 'sle-module-foo'
              prod.arch = system.products.first.arch
              prod.save!
              prod
            end
            let(:requested_uri) { '/repo' + free_product.repositories.first[:local_path] + '/repodata/repomd.xml' }

            its(:code) { is_expected.to eq '200' }
          end

          context 'when requesting a file in an activated SLES SAP repo on a SLE Micro system' do
            let(:free_product) do
              prod = FactoryBot.create(
                :product, :module, :with_mirrored_repositories
                )
              prod.identifier = 'sle-module-foo-sap'
              prod.arch = system.products.first.arch
              prod.save!
              prod
            end
            let(:requested_uri) { '/repo' + free_product.repositories.first[:local_path] + '/repodata/repomd.xml' }

            its(:code) { is_expected.to eq '403' }
          end

          context 'when requesting a file in an activated repo' do
            let(:requested_uri) { '/repo' + system.repositories.first[:local_path] + '/repodata/repomd.xml' }

            its(:code) { is_expected.to eq '200' }
          end

          context 'when requesting a directory in an activated repo' do
            let(:requested_uri) { '/repo' + system.repositories.first[:local_path] + '/' }

            its(:code) { is_expected.to eq '200' }
          end

          context 'when accessing product.license directory' do
            let(:requested_uri) { '/repo/some/uri/product.license/' }

            its(:code) { is_expected.to eq '200' }
          end

          context 'when accessing product with repos with special characters' do
            let(:product) do
              product = FactoryBot.create(:product, :with_service)
              product.service.repositories << repository
              product
            end

            let(:repository) do
              FactoryBot.create(
                :repository,
                external_url: 'https://updates.suse.com/$path/*with/.funky/(characters)/'
              )
            end

            let(:system) { FactoryBot.create(:system, :payg, :with_activated_product, product: product) }
            let(:requested_uri) { '/repo/$path/*with/.funky/(characters)/repodata/repomd.xml' }

            its(:code) { is_expected.to eq '200' }
          end

          context 'when accessing SLES12SP1 repos and SLES 11 is activated' do
            let(:system) { FactoryBot.create(:system, :with_activated_product, product: product) }
            let(:product) do
              FactoryBot.create(
                :product, :with_mirrored_repositories,
                identifier: 'SUSE_SLES', version: '11.4', arch: 'x86_64'
              )
            end

            context 'when requested path is not activated' do
              let(:requested_uri) { '/repo/SUSE/Products/SLE-Product-SLES/15/x86_64/product' }

              its(:code) { is_expected.to eq '403' }
            end

            context 'when requested path is version 12' do
              let(:requested_uri) { '/repo/SUSE/Updates/SLE-Module-Adv-Systems-Management/12/x86_64/update' }
              let(:data_export_double) { instance_double('DataExport::Handlers::Example') }
              let(:plugin_double) { instance_double('InstanceVerification::Providers::Example') }

              before do
                allow(InstanceVerification).to receive(:verify_instance).and_return(true)
                allow(DataExport::Handlers::Example).to receive(:new).and_return(data_export_double)
                allow(data_export_double).to receive(:export_rmt_data)
                allow(ZypperAuth).to receive(:zypper_auth_message)
              end

              its(:code) { is_expected.to eq '200' }
            end

            context 'when requested path is version 12.1' do
              let(:requested_uri) { '/repo/SUSE/Products/SLE-SERVER/12-SP1/x86_64/product' }

              before { allow(InstanceVerification).to receive(:verify_instance).and_return(true) }

              its(:code) { is_expected.to eq '200' }
            end
          end

          context 'when accessing SLES12SP1 repos and SLES 11 is not activated' do
            let(:system) { FactoryBot.create(:system, :with_activated_product, product: product) }
            let(:product) do
              FactoryBot.create(
                :product, :with_mirrored_repositories,
                identifier: 'SLES', version: '15', arch: 'x86_64'
              )
            end

            context 'when requested path is version 12' do
              let(:requested_uri) { '/repo/SUSE/Updates/SLE-Module-Adv-Systems-Management/12/x86_64/update' }

              its(:code) { is_expected.to eq '403' }
            end

            context 'when requested path is version 12.1' do
              let(:requested_uri) { '/repo/SUSE/Products/SLE-SERVER/12-SP1/x86_64/product' }

              its(:code) { is_expected.to eq '403' }
            end
          end

          context 'when system is SUMA' do
            let(:my_product) do
              FactoryBot.create(
                :product, :with_mirrored_repositories,
                identifier: 'SUSE-Manager-Server', version: '15', arch: 'x86_64'
                )
            end
            let(:system) { FactoryBot.create(:system, :payg, :with_activated_product, product: my_product) }

            let(:suma_prod_id) do
              system.products.find do |p|
                if p.identifier.include?('Manager')
                  return p.id
                end
              end
            end

            let(:suma_repo) do
              system.services.find do |service|
                if service.id == suma_prod_id
                  return service.repositories.first[:local_path]
                end
              end
            end
            let(:requested_uri) { '/repo' + suma_repo + '/repodata/repomd.xml' }

            context 'foo' do
              its(:code) { is_expected.to eq '200' }
            end
          end
        end
      end

      context 'wrong url' do
        let(:my_exception) { ActionController::RoutingError.new('foo') }
        let(:request) { ActionDispatch::TestRequest.new('a') }

        it 'logs a warning' do
          ActionDispatch::DebugExceptions.new('foo').log_error(request, my_exception)
        end
      end

      context 'OK url' do
        let(:request) { ActionDispatch::TestRequest.new('a') }
        let(:my_exception) { ActionController::ParameterMissing.new('standard') }
        let(:wrapper) do
          ActionDispatch::ExceptionWrapper.new(
            request.get_header('action_dispatch.backtrace_cleaner'),
            my_exception
          )
        end

        it 'logs error' do
          ActionDispatch::DebugExceptions.new('foo').log_error(request, wrapper)
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
