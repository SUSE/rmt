require 'rails_helper'

RSpec.describe Service, type: :model do
  it { is_expected.to belong_to :product }
  it { is_expected.to have_many :repositories }
  it { is_expected.to have_many :enabled_repositories }
  it { is_expected.to have_many :repositories_services_associations }
  it { is_expected.to have_many(:activations).dependent(:destroy) }
  it { is_expected.to have_many(:systems).through(:activations) }
  it { is_expected.to validate_presence_of :product_id }

  describe '#enabled_repositories' do
    context 'when has enabled and disabled repos' do
      subject { service.enabled_repositories }

      let(:service) { create(:service) }
      let(:enabled_repository) { create(:repository) }
      let(:disabled_repository) { create(:repository, enabled: false) }

      before do
        service.repositories << enabled_repository
        service.repositories << disabled_repository
      end

      it { is_expected.to include enabled_repository }
      it { is_expected.not_to include disabled_repository }
    end
  end

  describe '#name' do
    shared_examples 'service name' do |product_attributes, expected|
      subject { create(:service, product: product).name }

      let(:product) { create(:product, name: product_attributes[:name], release_type: product_attributes[:release_type], arch: product_attributes[:arch]) }

      it { is_expected.to eq(expected) }
    end

    it_behaves_like 'service name', { name: 'SLES Special Product 1', arch: 'x86_64' }, 'SLES_Special_Product_1_x86_64'
    it_behaves_like 'service name', { name: 'SLES Special Product 1', release_type: 'Online', arch: 'x86_64' }, 'SLES_Special_Product_1_Online_x86_64'
    it_behaves_like 'service name', { name: 'SLES Special Product 1', arch: 'unknown' }, 'SLES_Special_Product_1'
    it_behaves_like 'service name', { name: 'SLES Special Product 1', release_type: 'Online', arch: 'unknown' }, 'SLES_Special_Product_1_Online'
  end
end
