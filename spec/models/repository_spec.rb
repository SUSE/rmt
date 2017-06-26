require 'rails_helper'

RSpec.describe Repository, type: :model do
  subject { build(:repository) }
  let(:product) { create(:product, :with_repositories) }

  it { should have_many :products }
  it { should have_many :services }
  it { should have_many :systems }
  it { should have_many :repositories_services_associations }

  it { should have_db_column(:name).of_type(:string).with_options(null: false) }

  it 'responds to needed attributes' do
    expected_attributes = %i(
      id
      name
      external_url
      enabled
      autorefresh
      distro_target
      auth_token
      description
    )

    expect(subject.attributes.keys.map(&:to_sym)).to match_array expected_attributes
  end
end
