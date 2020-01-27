require 'rails_helper'

module StrictAuthentication
  RSpec.describe AuthenticationController, type: :request do
    subject { response }

    let(:system) { FactoryGirl.create(:system, :with_activated_product) }

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

        before { get '/api/auth/check', headers: auth_header.merge({ 'X-Original-URI': requested_uri }) }

        context 'when requested path is not activated' do
          let(:requested_uri) { '/repo/some/uri' }

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
            product = FactoryGirl.create(:product, :with_service)
            product.service.repositories << repository
            product
          end

          let(:repository) do
            FactoryGirl.create(
              :repository,
              external_url: 'https://updates.suse.com/$path/*with/.funky/(characters)/'
            )
          end

          let(:system) { FactoryGirl.create(:system, :with_activated_product, product: product) }
          let(:requested_uri) { '/repo/$path/*with/.funky/(characters)/repodata/repomd.xml' }

          its(:code) { is_expected.to eq '200' }
        end

        context 'when accessing SLES12SP1 repos and SLES 11 is activated' do
          let(:system) { FactoryGirl.create(:system, :with_activated_product, product: product) }
          let(:product) do
            FactoryGirl.create(
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

            its(:code) { is_expected.to eq '200' }
          end

          context 'when requested path is version 12.1' do
            let(:requested_uri) { '/repo/SUSE/Products/SLE-SERVER/12-SP1/x86_64/product' }

            its(:code) { is_expected.to eq '200' }
          end
        end

        context 'when accessing SLES12SP1 repos and SLES 11 is not activated' do
          let(:system) { FactoryGirl.create(:system, :with_activated_product, product: product) }
          let(:product) do
            FactoryGirl.create(
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
      end
    end
  end
end
