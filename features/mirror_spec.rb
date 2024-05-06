require File.expand_path('support/command_rspec_helper', __dir__)

describe 'mirror' do
  let(:files) { %w[repomd.xml repomd.xml.asc repomd.xml.key *-primary.xml.gz *-filelists.xml.gz *-other.xml.gz] }
  let(:path) { '/var/lib/rmt/public/repo/SUSE/Updates/SLE-Product-SLES/15' }

  before do
    `/usr/bin/rmt-cli repos enable 3114`
    `/usr/bin/rmt-cli mirror`
  end

  after do
    `/usr/bin/rmt-cli repos disable 3114`

    # cleanup files
    FileUtils.rm_r(path)
  end

  it do
    expect(File.join(path, 'repodata/repomd.xml')).to exist
    files.each do |filename_pattern|
      expect(`find /var/lib/rmt/public/ -name \'#{filename_pattern}\'`).to include(filename_pattern.delete('*'))
    end
  end
end

describe 'mirror multiple times' do
  let(:path) { '/var/lib/rmt/public/repo/SUSE/Updates/SLE-Product-SLES/15' }

  before do
    `/usr/bin/rmt-cli repos enable 3114`
    `/usr/bin/rmt-cli mirror`
    # mirror the repository twice to see the behaviour in this case
    `/usr/bin/rmt-cli mirror`
  end

  after do
    `/usr/bin/rmt-cli repos disable 3114`

    # cleanup files
    FileUtils.rm_r(path)
  end

  it 'does not create repodata/repodata' do
    expect(File.join(path, 'repodata', 'repodata')).not_to exist
  end
end
