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

  describe 'scopes' do
    describe '.only_mirrored' do
      subject { described_class.only_mirrored }

      let!(:mirrored) { create :repository, mirroring_enabled: true }

      before { create :repository, mirroring_enabled: false }

      it { is_expected.to contain_exactly(mirrored) }
    end

    describe '.only_enabled' do
      subject { described_class.only_enabled }

      let!(:enabled) { create :repository, enabled: true }

      before { create :repository, enabled: false }

      it { is_expected.to contain_exactly(enabled) }
    end

    describe '.only_installer_updates' do
      subject { described_class.only_installer_updates }

      let!(:installer_updates) { create :repository, installer_updates: true }

      before { create :repository, installer_updates: false }

      it { is_expected.to contain_exactly(installer_updates) }
    end

    describe '.only_scc' do
      subject { described_class.only_scc }

      let!(:official) { create :repository, scc_id: 1 }

      before { create :repository, scc_id: nil }

      it { is_expected.to contain_exactly(official) }
    end

    describe '.only_custom' do
      subject { described_class.only_custom }

      let!(:custom) { create :repository, scc_id: nil }

      before { create :repository, scc_id: 1 }

      it { is_expected.to contain_exactly(custom) }
    end
  end

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

    context 'with no subpath and no trailing slash' do
      let(:url) { 'http://localhost.com' }

      it { is_expected.to eq '/' }
    end

    context 'with no subpath but with a trailing slash' do
      let(:url) { 'http://localhost.com/' }

      it { is_expected.to eq '/' }
    end

    context 'with a subpath and no trailing slash' do
      let(:url) { 'http://localhost.com/foo/bar' }

      it { is_expected.to eq '/foo/bar' }
    end
  end

  describe '#destroy' do
    context 'when it is an official repository' do
      subject { repository.destroy }

      let!(:repository) { create :repository }

      it { is_expected.to be_falsey }
    end

    context 'when it is a custom repository' do
      subject { repository.destroy }

      let!(:repository) { create :repository, :custom }

      it { is_expected.to be_truthy }
    end
  end
end
