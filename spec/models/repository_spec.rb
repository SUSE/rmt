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
    describe '.only_mirroring_enabled' do
      subject { described_class.only_mirroring_enabled }

      let!(:mirrored) { create :repository, mirroring_enabled: true }

      before { create :repository, mirroring_enabled: false }

      it { is_expected.to contain_exactly(mirrored) }
    end

    describe '.only_fully_mirrored' do
      subject { described_class.only_fully_mirrored }

      let!(:mirrored) { create :repository, mirroring_enabled: true, last_mirrored_at: Time.zone.now }

      before { create :repository, mirroring_enabled: true }

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

  describe '#make_friendly_id' do
    subject(:friendly_id) { described_class.make_friendly_id(input) }

    let(:input) { 'my repo' }

    it 'creates a friendly_id' do
      expect(friendly_id).to eq('my-repo')
    end

    it 'will take the requested friendly_id if it can' do
      create(:repository, friendly_id: 'my-repo-1')
      expect(friendly_id).to eq('my-repo')
    end

    it 'will append to the requested friendly_id if taken' do
      create(:repository, friendly_id: 'my-repo')
      expect(friendly_id).to eq('my-repo-1')
    end

    it 'will append to the requested friendly_id if taken with complexity' do
      create(:repository, friendly_id: 'my-repo')
      create(:repository, friendly_id: 'my-repo-1')
      create(:repository, friendly_id: 'my-repo-1-1')
      create(:repository, friendly_id: 'my-repo-3')
      create(:repository, friendly_id: 'my-repo-99999')
      expect(friendly_id).to eq('my-repo-100000')
    end

    it 'does not consider negative numbers in appends' do
      create(:repository, friendly_id: 'my-repo')
      create(:repository, friendly_id: 'my-repo--1')
      expect(friendly_id).to eq('my-repo-1')
    end

    context 'id is not in english' do
      let(:input) { 'モルモット' }

      it 'allows characters from other languages' do
        expect(friendly_id).to eq('モルモット')
      end

      it 'will append to non-english friendly_ids' do
        create(:repository, friendly_id: 'モルモット')
        expect(friendly_id).to eq('モルモット-1')
      end
    end

    context 'numeric friendly_ids' do
      let(:input) { '9999' }

      it 'accepts a numeric id' do
        expect(friendly_id).to eq('9999')
      end

      it 'does not append to a numeirc id' do
        create(:repository, friendly_id: '9999')
        expect(friendly_id).to eq('9999')
      end

      it 'does not append to a numeric id with complexity' do
        create(:repository, friendly_id: '9999')
        create(:repository, friendly_id: '9999-1')
        create(:repository, friendly_id: '9999-1-1')
        create(:repository, friendly_id: '9999-9999')
        expect(friendly_id).to eq('9999')
      end
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
