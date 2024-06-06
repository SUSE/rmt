require File.expand_path('support/command_rspec_helper', __dir__)

describe 'mirror' do
  let(:files) { %w[repomd.xml repomd.xml.asc repomd.xml.key *-primary.xml.gz *-filelists.xml.gz *-other.xml.gz] }
  let(:path) { '/var/lib/rmt/public/repo/SUSE/Products/SLE-Product-SLES/15-SP5/x86_64' }

  before do
    `/usr/bin/rmt-cli repos enable 5664`
    `/usr/bin/rmt-cli mirror`
  end

  after do
    `/usr/bin/rmt-cli repos disable 5664`

    # cleanup files
    FileUtils.rm_r(path)
  end

  let(:metadata_files) { %w[repomd.xml repomd.xml.asc repomd.xml.key *-primary.xml.gz *-filelists.xml.gz *-other.xml.gz] }

  it 'has valid metadata mirrored' do
    expect(File.exist?(File.join(path, 'repodata/repomd.xml'))).to eq(true)

    metadata_files.each do |filename_pattern|
      expect(`find #{File.join(path, 'product', 'repodata')} -maxdepth 1 -name \'#{filename_pattern}\'`).to include(filename_pattern.delete('*'))
    end
  end

  let(:license_files) { %w[license.txt directory.yast license.de.txt] }

  it 'has licenses correctly mirrored' do
    license_files.each do |filename_pattern|
      expect(`find #{File.join(path, 'product.license')} -maxdepth 1 -name \'#{filename_pattern}\'`).to include(filename_pattern.delete('*'))
    end
  end

  it 'has rpms correctly mirrored' do
    expect(`find #{File.join(path, 'product', 'x86_64')} -maxdepth 1 -name sles-release-*.rpm`).to include('sles-release')
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
