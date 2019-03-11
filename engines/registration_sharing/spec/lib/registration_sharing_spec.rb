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
    let(:system) { FactoryGirl.create(:system) }
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

  describe '.config_data_dir' do
    before { allow(Settings).to receive(:[]).with(:regsharing).and_return(nil) }

    context 'when regsharing section is missing' do
      it 'returns the default dir' do
        expect(described_class.config_data_dir).to eq(RegistrationSharing::RMT_REGSHARING_DEFAULT_DATA_DIR)
      end
    end
  end

  describe '.config_api_secret' do
    before { allow(Settings).to receive(:[]).with(:regsharing).and_return(nil) }

    context 'when regsharing section is missing' do
      it 'returns nil' do
        expect(described_class.config_api_secret).to eq(nil)
      end
    end
  end

  describe '.config_ca_path' do
    before { allow(Settings).to receive(:[]).with(:regsharing).and_return(nil) }

    context 'when regsharing section is missing' do
      it 'returns nil' do
        expect(described_class.config_ca_path).to eq(nil)
      end
    end
  end
end
