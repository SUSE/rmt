require 'rails_helper'

RSpec.describe Service, type: :model do
  it { is_expected.to belong_to :product }
  it { is_expected.to have_many :repositories }
  it { is_expected.to have_many :enabled_repositories }
  it { is_expected.to have_many :repositories_services_associations }
  it { is_expected.to have_many :activations }
  it { is_expected.to have_many(:systems).through(:activations) }
  it { is_expected.to validate_presence_of :product_id }

  describe '#enabled_repositories' do
    context 'when has enabled and disabled repos' do
      subject { service.enabled_repositories }

      let(:service) { FactoryGirl.create(:service) }
      let(:enabled_repository) { FactoryGirl.create(:repository) }
      let(:disabled_repository) { FactoryGirl.create(:repository, enabled: false) }

      before do
        service.repositories << enabled_repository
        service.repositories << disabled_repository
      end

      it { is_expected.to include enabled_repository }
      it { is_expected.not_to include disabled_repository }
    end
  end
end
