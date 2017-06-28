require 'rails_helper'

RSpec.describe Repository, type: :model do
  subject { build(:repository) }
  let(:product) { create(:product, :with_repositories) }

  it { should have_many :products }
  it { should have_many :services }
  it { should have_many :systems }
  it { should have_many :repositories_services_associations }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:external_url) }

  it { should have_db_column(:name).of_type(:string).with_options(null: false) }
  it { should have_db_column(:external_url).of_type(:string).with_options(null: false) }
end
