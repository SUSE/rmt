require 'rails_helper'

RSpec.describe RMT::Mirror do
  let(:url) { 'http://some.test.us/path/directory/' }
  let(:base_dir) { '/non/existing/' }
  let(:repository) { create :repository, external_url: url }

  let(:mirror) do
    described_class.new(repository: repository,
                        base_dir: base_dir,
                        logger: nil,
                        mirror_sources: false,
                        is_airgapped: false)
  end

  describe '#detect_repository_type' do
    context 'repomd repository' do
      it 'detects a repomd repository' do
        expect(mirror.detect_repository_type).to eq(:repomd)
      end
    end

    context 'debian flat repository' do
      it 'detects a flat debian repository' do
        expect(mirror.detect_repository_type).to eq(:debian)
      end
    end

    context 'debian repository' do
      it 'detects a full blown debian repository and raises'
    end

    context 'unknown repository type' do
      it 'raises if a unknown repository type is detected'
    end
  end
end
