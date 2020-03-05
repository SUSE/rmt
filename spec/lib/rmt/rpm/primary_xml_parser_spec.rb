require 'rails_helper'

RSpec.describe RMT::Rpm::ModifiedPrimaryXmlParser do
  describe '#parse' do
    let(:expected_result) do
      [
        RepomdParser::Reference.new(
          location: 'apples-0.1-0.x86_64.rpm',
          checksum_type: 'sha256',
          checksum: '5c4e3fa1624bd23251eecdda9c7fcefad045995a9eaed527d06dd8510cfe2851',
          type: :rpm,
          size: 1934,
          arch: 'x86_64',
          version: '0.1',
          release: '0',
          name: 'apples',
          build_time: '2017-07-19 08:34:13 UTC'
        ),
        RepomdParser::Reference.new(
          location: 'apples-0.2-0.x86_64.rpm',
          checksum_type: 'sha256',
          checksum: 'a9fdc5517f48d2b12c780deb080c8a619f3d440b0b50c2c30b5c9350352db463',
          type: :rpm,
          size: 1950,
          arch: 'x86_64',
          version: '0.2',
          release: '0',
          name: 'apples',
          build_time: '2017-07-19 08:35:44 UTC'
        ),
        RepomdParser::Reference.new(
          location: 'oranges-0.1-0.x86_64.rpm',
          checksum_type: 'sha256',
          checksum: 'a38de0c943388127b9c746e7772d694055ec255706ececd563fb55d13b01b4f3',
          type: :rpm,
          size: 1933,
          arch: 'x86_64',
          version: '0.1',
          release: '0',
          name: 'oranges',
          build_time: '2017-07-19 08:38:03 UTC'
        ),
        RepomdParser::Reference.new(
          location: 'oranges-0.2-0.x86_64.rpm',
          checksum_type: 'sha256',
          checksum: 'd38a6b65326e471540ce5105677411035d437a177634a77088dfb73e34461f37',
          type: :rpm,
          size: 1949,
          arch: 'src',
          version: '0.2',
          release: '0',
          name: 'oranges',
          build_time: '2017-07-19 08:39:19 UTC'
        )
      ]
    end

    context 'plain XML with mirror=false' do
      let(:references) do
        described_class.new(
          file_fixture('dummy_repo/repodata/abf421e45af5cd686f050bab3d2a98e0a60d1b5ca3b07c86cb948fc1abfa675e-primary.xml'),
          mirror_src = false
        ).parse
      end

      it 'references rpm files with mirror=false' do
        expect(references).to eq(expected_result.first expected_result.size - 1)
      end
    end

    context 'plain XML with mirror=true' do
      let(:references) do
        described_class.new(
          file_fixture('dummy_repo/repodata/abf421e45af5cd686f050bab3d2a98e0a60d1b5ca3b07c86cb948fc1abfa675e-primary.xml'),
          mirror_src=true
        ).parse
      end

      it 'references rpm files with mirror=true' do
        # the last element shouldn't be removed from the expected results this time as mirror=true
        # even though arch=src for the last package
        expect(references).to eq(expected_result)
      end
    end

    context 'gzipped XML' do
      let(:references) do
        described_class.new(
          file_fixture('dummy_repo/repodata/abf421e45af5cd686f050bab3d2a98e0a60d1b5ca3b07c86cb948fc1abfa675e-primary.xml.gz'),
          mirror_src = false
        ).parse
      end

      it 'references rpm files with mirror=false' do
        # the last element should be removed from the expected results as it has arch=src
        expect(references).to eq(expected_result.first expected_result.size - 1)
      end
    end
  end
end
