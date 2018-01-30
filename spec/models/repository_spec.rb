require 'rails_helper'

RSpec.describe Repository, type: :model do
  subject { build(:repository) }

  let(:product) { create(:product, :with_mirrored_repositories) }

  it { is_expected.to have_many :products }
  it { is_expected.to have_many :services }
  it { is_expected.to have_many :systems }
  it { is_expected.to have_many :repositories_services_associations }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:external_url) }

  it { is_expected.to have_db_column(:name).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:external_url).of_type(:string).with_options(null: false) }

  describe '.make_local_path' do
    subject { described_class.make_local_path(url) }

    context 'old SLES repo' do
      let(:url) { 'https://updates.suse.com/repo/$RCE/SLES11-Pool/sle-11-x86_64/' }

      it { is_expected.to eq('/$RCE/SLES11-Pool/sle-11-x86_64/') }
    end

    context 'new SLES repo' do
      let(:url) { 'https://updates.suse.com/SUSE/Products/SLE-SERVER/12-SP2/x86_64/product/' }

      it { is_expected.to eq('/SUSE/Products/SLE-SERVER/12-SP2/x86_64/product/') }
    end

    context 'generic repo that starts with "/repo"' do
      let(:url) { 'https://example.com/repo/dummy_repo/' }

      it { is_expected.to eq('/repo/dummy_repo/') }
    end
  end

  describe '#remove_repository' do
    let(:custom_repository) { create :repository, :custom }
    let(:suse_repository) { create :repository }

    it('has custom repository') { expect(Repository.find_by(id: custom_repository.id)).not_to be_nil }
    it('removes custom repositories') { expect(custom_repository.destroy).not_to be_falsey }

    it('has non-custom repository') { expect(Repository.find_by(id: suse_repository.id)).not_to be_nil }
    it('does not remove non-custom repositories') { expect(suse_repository.destroy).to be_falsey }
  end

  describe 'local_path' do
    it(:handles_empty_root) { expect(Repository.make_local_path('http://localhost.com')).to eq('/') }
    it(:handles_empty_root_trailing_slash) { expect(Repository.make_local_path('http://localhost.com/')).to eq('/') }
    it(:handles_subpath) { expect(Repository.make_local_path('http://localhost.com/foo/bar')).to eq('/foo/bar') }
    it(:handles_subpath_trailing_slash) { expect(Repository.make_local_path('http://localhost.com/foo/bar/')).to eq('/foo/bar/') }
  end

  describe '#set_unique_id' do
    subject { create :repository, :custom, external_url: 'http://example.com/' }

    its(:unique_id) { is_expected.to eq('a6bf1757fff057f266b697df9cf176fd') }
  end
end
