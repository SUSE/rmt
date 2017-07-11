require 'rails_helper'

RSpec.describe Api::Connect::V3::Repositories::InstallerController do
  include_context 'version header', 3

  let(:url) { connect_default_repositories_installer_url }

  describe '#show' do
    before { get url }
    subject { response }

    its(:body) { is_expected.to eq '{}' }
    its(:code) { is_expected.to eq('422') }
  end
end
