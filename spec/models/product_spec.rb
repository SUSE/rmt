require 'rails_helper'

RSpec.describe Product, type: :model do
  subject { create :product }

  let(:extension) { create :product }
  let(:additional_extension) { create :product }

  it { should have_one :service }
  it { should have_many :repositories }
  it { should have_many :bases }
  it { should have_many :extensions }

  it 'responds to needed attributes' do
    expected_attributes = [
        :id,
        :name,
        :shortname,
        :free,
        :arch,
        :identifier,
        :release_type,
        :description,
        :cpe,
        :former_identifier,
        :product_type,
        :available,
        :eula_url,
        :friendly_name,
        :product_class,
        :release_stage,
        :version
    ]

    expect(subject.attributes.keys.map(&:to_sym).sort).to match_array expected_attributes
  end

  it 'returns a list of product extensions for base product' do
    subject.extensions << extension
    expect(subject.extensions).to_not be_empty
    expect(subject.extensions).to include extension
    expect(extension.bases).to include subject
  end

  it 'returns a list of base products for product extension' do
    extension.bases << subject
    expect(extension.bases).to_not be_empty
    expect(extension.bases).to include subject
    expect(subject.extensions).to include extension
  end

  it 'product extension might have additional extensions' do
    extension.bases << subject
    expect(extension.bases).to_not be_empty
    expect(extension.bases).to include subject

    extension.extensions << additional_extension
    expect(extension.extensions).not_to be_empty
    expect(extension.extensions).to include additional_extension
    expect(additional_extension.bases).to include extension
  end

  it 'checks whether the product is a base product' do
    expect(subject.base?).to eq true
  end

  it 'checks whether the product is an extension product' do
    extension.product_type = 'extension'
    expect(extension.extension?).to eq true
  end

  it 'checks whether the product has extension' do
    subject.extensions << extension
    expect(subject.has_extension?).to eq true
  end
end
