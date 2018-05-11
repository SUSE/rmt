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
      it 'returns only mirrored repos' do
        mirrored = create :repository, mirroring_enabled: true
        create :repository, mirroring_enabled: false

        expect(Repository.only_mirrored).to contain_exactly(mirrored)
      end
    end

    describe '.only_enabled' do
      it 'returns only enabled repos' do
        enabled = create :repository, enabled: true
        create :repository, enabled: false

        expect(Repository.only_enabled).to contain_exactly(enabled)
      end
    end

    describe '.only_installer_updates' do
      it 'returns only repos that are installer updates' do
        installer_updates = create :repository, installer_updates: true
        create :repository, installer_updates: false

        expect(Repository.only_installer_updates).to contain_exactly(installer_updates)
      end

      # NOTE: It's unknown to me (Hernan) why this scope does this.
      it 'clears existing where-clauses' do
        installer_updates = create :repository, installer_updates: true
        create :repository, installer_updates: false

        expect(Repository.where(installer_updates: false).only_installer_updates).to contain_exactly(installer_updates)
      end
    end

    describe '.only_scc' do
      it 'returns only official repositories' do
        official = create :repository, scc_id: 1
        create :repository, scc_id: nil

        expect(Repository.only_scc).to contain_exactly(official)
      end
    end

    describe '.only_custom' do
      it 'returns only custom repositories' do
        custom = create :repository, scc_id: nil
        create :repository, scc_id: 1

        expect(Repository.only_custom).to contain_exactly(custom)
      end
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
