require 'rails_helper'

RSpec.describe System, type: :model do
  let(:system) { create :system_with_activated_base_product }

  subject { system }

  it { should have_many :activations }
  it { should have_many(:services).through(:activations) }
  it { should have_many(:repositories).through(:services) }

  it 'generates secure and unique SCC token' do
    login = described_class.generate_secure_login
    expect(login).to include 'SCC_'
    expect(login.length).to eq 36
    expect(System.find_by_login(login)).to be nil
  end

  it 'generates secure password' do
    password = described_class.generate_secure_password
    expect(password.length).to eq 16
  end

  it 'can be found via login and password' do
    subject.password = 'password'
    subject.save!
    ret = System.find_by_login_and_password(subject.login, subject.password)
    expect(subject.login).to eq ret.login
    expect(subject.password).to eq ret.password
  end

  it 'deletes associated activations on system destroy' do
    activation = create(:activation)
    activation.system.destroy

    expect { activation.reload }.to raise_error ActiveRecord::RecordNotFound
  end
end
