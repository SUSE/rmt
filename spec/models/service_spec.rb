require 'rails_helper'

RSpec.describe Service, type: :model do
  subject { FactoryGirl.create(:service) }

  it { should belong_to :product }
  it { should have_many :repositories }
  it { should have_many :enabled_repositories }
  it { should have_many :repositories_services_associations }
  it { should have_many :activations }
  it { should have_many(:systems).through(:activations) }
  it { should validate_presence_of :product_id }

  context 'when has enabled and disabled repos' do
    let(:enabled_repository) { FactoryGirl.create(:repository) }
    let(:disabled_repository) { FactoryGirl.create(:repository, enabled: false) }

    before do
      subject.repositories << enabled_repository
      subject.repositories << disabled_repository
    end

    its(:enabled_repositories) { is_expected.to include enabled_repository }
    its(:enabled_repositories) { is_expected.to_not include disabled_repository }
  end
end
