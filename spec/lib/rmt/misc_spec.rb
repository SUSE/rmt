require 'rails_helper'

describe RMT::Misc do
  describe '.make_smt_service_name' do
    subject { described_class.make_smt_service_name(url) }

    context 'with HTTP URL' do
      let(:url) { 'http://example.com' }

      it { is_expected.to eq('SMT-http_example_com') }
    end

    context 'with HTTPS URL' do
      let(:url) { 'https://example.com' }

      it { is_expected.to eq('SMT-http_example_com') }
    end
  end
end
