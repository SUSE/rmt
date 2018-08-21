require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'mirror' do
  let(:files) { %w'repomd.xml repomd.xml.asc repomd.xml.key *-primary.xml.gz *-filelists.xml.gz *-other.xml.gz' }

  before do
    system '/usr/bin/rmt-cli repos enable 3114'
    command '/usr/bin/rmt-cli mirror'
  end

  after do
    system '/usr/bin/rmt-cli repos disable 3114'

    # cleanup files
    files.each do |filename_pattern|
      %x"rm $(find /var/lib/rmt/public/ -name #{filename_pattern})"
    end
  end

  it do
    files.each do |filename_pattern|
      expect( %x"find /var/lib/rmt/public/ -name #{filename_pattern}").to include(filename_pattern.gsub('*', ''))
    end
  end
end
