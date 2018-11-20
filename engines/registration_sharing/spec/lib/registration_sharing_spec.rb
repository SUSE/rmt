require 'rails_helper'

describe RegistrationSharing do
  describe '.save_for_sharing' do
    before do
      allow(Settings).to receive(:[]).with(:regsharing).and_return(config).at_least(:once)
      Timecop.freeze(time)
      described_class.save_for_sharing(system)
    end

    after do
      Timecop.return
      FileUtils.remove_entry_secure temp_dir
    end

    let(:time) { Time.zone.now }
    let(:system) { FactoryGirl.create(:registration_sharing_system) }
    let(:temp_dir) { Dir.mktmpdir }
    let(:peers) { [ 'example.org', 'example.com' ] }
    let(:config) { { peers: peers, data_dir: temp_dir } }

    it 'creates sync file for peer' do
      peers.each do |peer|
        filename = File.join(temp_dir, peer, system.login)
        expect(File.exist?(filename)).to eq(true)
      end
    end

    it 'sync file contains timestamp' do
      peers.each do |peer|
        filename = File.join(temp_dir, peer, system.login)
        expect(File.read(filename)).to eq(time.to_f.to_s + "\n")
      end
    end
  end
end
