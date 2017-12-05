require 'rails_helper'

RSpec.describe RMT::CLI::Export do
  let(:path) { '/mnt/usb' }

  describe 'settings' do
    it 'writes ids of enabled repos to file' do
      create :repository, mirroring_enabled: true, id: 123
      create :repository, mirroring_enabled: false
      expect(File).to receive(:write).with("#{path}/repos.json", '[123]')
      described_class.start(['settings', path])
    end
  end

  describe 'data' do
    it 'calls sync with special params' do
      expect_any_instance_of(RMT::SCC).to receive(:export).with(path)
      described_class.start(['data', path])
    end
  end

  describe 'repos' do
    let(:repo_ids_from_file) { [42, 69] }
    let(:repos_from_file) do
      repo_ids_from_file.map { |id| create :repository, id: id }
    end
    let(:mirror_double) do
      double = instance_double(RMT::Mirror)
      expect(double).to receive(:mirror).exactly(2).times
      double
    end

    before { create :repository, id: 666, mirroring_enabled: true }

    it 'reads repo ids from file at path and mirrors these repos' do
      expect(File).to receive(:read).with("#{path}/repos.json").and_return repo_ids_from_file.to_json
      expect(RMT::Mirror).to receive(:new).exactly(2).times { mirror_double }
      repos_from_file
      described_class.start(['repos', path])
    end
  end
end
