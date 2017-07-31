require 'rails_helper'

RSpec.describe RMT::Rpm::DeltainfoXmlParser do
  let(:parser) do
    described_class.new(
      file_fixture('dummy_repo/repodata/a546b430098b8a3fb7d65493a9ce608fafcb32f451d0ce8bf85410191f347cc3-deltainfo.xml.gz')
    )
  end

  before { parser.parse }

  it 'references drpm files' do
    expect(parser.referenced_files).to eq [
      RMT::Rpm::FileEntry.new(
        'apples-0.1-0.x86_64.drpm',
        'sha256',
        'd5da95c8606a3de101d543e7d90c96f59b9f7cf50a8c944cbee889505401565e',
        :drpm
      ),
      RMT::Rpm::FileEntry.new(
        'oranges-0.1-0.x86_64.drpm',
        'sha256',
        'b0ec989937ef76c88cedb50848cc111bf2f3bcbb490fa8c8c1180aa4a9a63d73',
        :drpm
      )
    ]
  end
end
