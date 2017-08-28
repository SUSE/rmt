require 'rails_helper'

RSpec.describe Api::HealthController do
  describe '#status' do
    before { get '/api/health/status.json' }

    subject { json_response }

    it { is_expected.to eq(state: 'online') }
  end
end
