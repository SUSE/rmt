require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'mirror' do
  let(:files) { %w'repomd.xml repomd.xml.asc repomd.xml.key *-primary.xml.gz *-filelists.xml.gz *-other.xml.gz' }

  before do
    `/usr/bin/rmt-cli repos enable 3114`
    `/usr/bin/rmt-cli mirror`
  end

  after do
    `/usr/bin/rmt-cli repos disable 3114`

    # cleanup files
    FileUtils.rm_r('/var/lib/rmt/public/repo/SUSE/Updates/SLE-Product-SLES/15')
  end

  it do
    files.each do |filename_pattern|
      expect(`find /var/lib/rmt/public/ -name \'#{filename_pattern}\'`).to include(filename_pattern.gsub('*', ''))
    end
  end
end
