require 'rails_helper'

RSpec.describe RMT::Rpm::RepomdXmlParser do
  let(:parser) { described_class.new(file_fixture('dummy_repo/repodata/repomd.xml')) }

  before { parser.parse }

  it 'references repodata files' do
    expect(parser.referenced_files).to eq [
      RMT::Rpm::FileEntry.new(
        'repodata/837fb50abc9680b1e11e050901a56721855a5e854e85e46ceaad2c6816297e69-filelists.xml.gz',
        'sha256',
        '837fb50abc9680b1e11e050901a56721855a5e854e85e46ceaad2c6816297e69',
        :filelists
      ),
      RMT::Rpm::FileEntry.new(
        'repodata/a546b430098b8a3fb7d65493a9ce608fafcb32f451d0ce8bf85410191f347cc3-deltainfo.xml.gz',
        'sha256',
        'a546b430098b8a3fb7d65493a9ce608fafcb32f451d0ce8bf85410191f347cc3',
        :deltainfo
      ),
      RMT::Rpm::FileEntry.new(
        'repodata/2d12587a74d924bad597fd8e25b8955270dfbe7591e020f9093edbb4a0d04444-other.xml.gz',
        'sha256',
        '2d12587a74d924bad597fd8e25b8955270dfbe7591e020f9093edbb4a0d04444',
        :other
      ),
      RMT::Rpm::FileEntry.new(
        'repodata/abf421e45af5cd686f050bab3d2a98e0a60d1b5ca3b07c86cb948fc1abfa675e-primary.xml.gz',
        'sha256',
        'abf421e45af5cd686f050bab3d2a98e0a60d1b5ca3b07c86cb948fc1abfa675e',
        :primary
      )
    ]
  end
end
