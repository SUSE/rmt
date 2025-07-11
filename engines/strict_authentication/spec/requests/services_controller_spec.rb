require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe ServicesController, type: :request do
  describe '#show' do
    let(:system) { FactoryBot.create(:system, :payg) }
    let(:service) { FactoryBot.create(:service, :with_repositories) }
    let(:activated_service) do
      service = FactoryBot.create(:service, :with_repositories)
      system.services << service
      system.save!
      service
    end


    describe 'HTTP response' do
      context 'without authentication' do
        subject { response }

        context 'when service doesn\'t exist' do
          before { get '/services/0' }
          its(:code) { is_expected.to eq '401' }
        end

        context 'when service exists' do
          before { get "/services/#{service.id}" }
          its(:code) { is_expected.to eq '401' }
        end
      end

      context 'with authentication' do
        subject { response }

        include_context 'auth header', :system, :login, :password

        let(:headers) { auth_header }

        context 'when service doesn\'t exist' do
          before { get '/services/0', headers: headers }
          its(:code) { is_expected.to eq '403' }
          its(:body) { is_expected.to eq 'Product is not registered' }
        end

        context 'when service is not registered' do
          before do
            headers['X-Instance-Data'] = Base64.strict_encode64('IMDS')
            get "/services/#{service.id}", headers: headers
          end

          its(:code) { is_expected.to eq '403' }
          its(:body) { is_expected.to eq 'Product is not registered' }
        end

        context 'when service is registered' do
          before do
            headers['X-Instance-Data'] = Base64.strict_encode64('IMDS')
            allow_any_instance_of(InstanceVerification::Providers::Example).to(
              receive(:instance_valid?).and_return(true)
            )
            allow(File).to receive(:directory?)
            allow(Dir).to receive(:mkdir)
            allow(FileUtils).to receive(:touch)
            allow(InstanceVerification).to receive(:reg_code_in_cache?).and_return(nil)
            allow(InstanceVerification).to receive(:update_cache)
            get "/services/#{activated_service.id}", headers: headers
          end
          its(:code) { is_expected.to eq '200' }
        end
      end
    end

    describe 'response XML URLs' do
      include_context 'auth header', :system, :login, :password

      before do
        headers['X-Instance-Data'] = Base64.strict_encode64('IMDS')
        allow_any_instance_of(InstanceVerification::Providers::Example).to(
          receive(:instance_valid?).and_return(true)
        )
        allow(File).to receive(:directory?)
        allow(Dir).to receive(:mkdir)
        allow(FileUtils).to receive(:touch)
        allow(InstanceVerification).to receive(:reg_code_in_cache?).and_return(nil)
        allow(InstanceVerification).to receive(:update_cache)
        get "/services/#{activated_service.id}", headers: headers
      end

      include_context 'auth header', :system, :login, :password

      subject { xml_urls }

      let(:headers) { auth_header }
      let(:xml_urls) do
        doc = Nokogiri::XML::Document.parse(response.body)
        repo_items = doc.xpath('/repoindex/repo')
        repo_items.map { |r| r.attr(:url) }
      end
      let(:model_urls) do
        activated_service.repositories.reject(&:installer_updates).map do |repo|
          RMT::Misc.make_repo_url('http://www.example.com', repo.local_path, activated_service.name)
        end
      end

      its(:length) { is_expected.to eq(service.repositories.length - 1) }
      it { is_expected.to eq(model_urls) }
    end
  end
end

# rubocop:enable RSpec/NestedGroups
