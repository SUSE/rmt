require 'rails_helper'
require 'registration_sharing/sync_job'

describe RegistrationSharing::SyncJob do
  let(:peer) { 'example.org' }
  let(:system_login) { 'SCC_testtesttest' }
  let(:sync_job) { described_class.new }
  let(:data_dir) { Dir.mktmpdir }
  let(:peer_dir) { File.join(data_dir, peer) }
  let(:system_file) { File.join(peer_dir, system_login) }

  before do
    allow(Settings).to receive(:[]).with(:regsharing).and_return({ peers: [ peer ], data_dir: data_dir })
    Dir.mkdir(peer_dir)
    File.open(system_file, 'w') { |file| file.write('test') }
  end

  after { FileUtils.remove_entry_secure(data_dir) if File.exist?(data_dir) }

  describe '#sync_registrations' do
    let(:client_double) { instance_double(RegistrationSharing::Client) }

    context 'when sync API request succeeds' do
      it 'removes system file' do
        expect(RegistrationSharing::Client).to receive(:new).with(peer, system_login).and_return(client_double)
        expect(client_double).to receive(:sync_system).and_return(true)
        sync_job.run
        expect(File.exist?(system_file)).to eq(false)
      end
    end

    context 'when sync API request succeeds and system file has changed' do
      it 'keeps system file' do
        expect(RegistrationSharing::Client).to receive(:new).with(peer, system_login).and_return(client_double)
        expect(client_double).to receive(:sync_system) do
          File.open(system_file, 'w') { |f| f.write('changed content') }
          true
        end
        sync_job.run
        expect(File.exist?(system_file)).to eq(true)
      end
    end

    context 'when sync API request fails' do
      it 'keeps system file' do
        expect(RegistrationSharing::Client).to receive(:new).with(peer, system_login).and_return(client_double)
        expect(client_double).to receive(:sync_system).and_raise('Request failed')
        sync_job.run
        expect(File.exist?(system_file)).to eq(true)
      end
    end
  end
end
