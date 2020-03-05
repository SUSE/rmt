require 'rails_helper'

RSpec.describe RMT::Rpm::ModifiedDeltainfoXmlParser do
  let(:expected_result) do [
    RepomdParser::Reference.new(
      location: 'apples-0.1-0.x86_64.drpm',
      checksum_type: 'sha256',
      checksum: 'd5da95c8606a3de101d543e7d90c96f59b9f7cf50a8c944cbee889505401565e',
      type: :drpm,
      size: 2087,
      arch: 'x86_64',
    ),
    RepomdParser::Reference.new(
      location: 'oranges-0.1-0.x86_64.drpm',
      checksum_type: 'sha256',
      checksum: 'b0ec989937ef76c88cedb50848cc111bf2f3bcbb490fa8c8c1180aa4a9a63d73',
      type: :drpm,
      size: 2083,
      arch: 'src',
    )
  ]
  end

  context 'plain XML with mirror=false' do
    let(:references) do
      described_class.new(
        file_fixture('dummy_repo/repodata/a546b430098b8a3fb7d65493a9ce608fafcb32f451d0ce8bf85410191f347cc3-deltainfo.xml.gz'),
        mirror_src = false
      ).parse
    end

    it 'references drpm files with mirror=false' do
      # the last element should be removed from the expected results as it has arch=src
      expect(references).to eq(expected_result.first expected_result.size - 1)
    end
  end

  context 'plain XML with mirror=true' do
    let(:references) do
      described_class.new(
        file_fixture('dummy_repo/repodata/a546b430098b8a3fb7d65493a9ce608fafcb32f451d0ce8bf85410191f347cc3-deltainfo.xml.gz'),
        mirror_src = true
      ).parse
    end

    it 'references drpm files with mirror=true' do
      # all the packages should be returned this time as mirror=true
      # even though arch=src for the last package
      expect(references).to eq(expected_result)
    end
  end
end
