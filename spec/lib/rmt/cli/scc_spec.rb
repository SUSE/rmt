require 'rails_helper'

describe RMT::CLI::Scc do
  describe 'sync-systems' do
    subject(:command) { described_class.start(['sync-systems']) }

    it 'runs sync_systems' do
      expect_any_instance_of(RMT::SCC).to receive(:sync_systems)
      command
    end
  end
end
