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

  it 'has enabled/disabled repositories' do
    enabled_repository = FactoryGirl.create(:repository)
    disabled_repository = FactoryGirl.create(:repository, enabled: false)

    subject.repositories << enabled_repository
    subject.repositories << disabled_repository

    expect(subject.enabled_repositories).to include enabled_repository
    expect(subject.enabled_repositories).to_not include disabled_repository
  end
end
