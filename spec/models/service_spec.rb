require 'rails_helper'

RSpec.describe Service, type: :model do
  it { should belong_to :product }
  it { should have_many :repositories }
  it { should have_many :enabled_repositories }
  it { should have_many :repositories_services_associations }
  it { should have_many :activations }
  it { should have_many(:systems).through(:activations) }
  it { should validate_presence_of :product_id }

  describe '#enabled_repositories' do
    context 'when has enabled and disabled repos' do
      let(:service) { FactoryGirl.create(:service) }
      subject { service.enabled_repositories }

      let(:enabled_repository) { FactoryGirl.create(:repository) }
      let(:disabled_repository) { FactoryGirl.create(:repository, enabled: false) }

      before do
        service.repositories << enabled_repository
        service.repositories << disabled_repository
      end

      it { is_expected.to include enabled_repository }
      it { is_expected.to_not include disabled_repository }
    end
  end
end
