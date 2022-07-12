shared_examples 'responds with a new token' do
  it 'responds with a new token' do
    get :service, params: { id: 1 }

    expect(response.status).to eq 404
    expect(response.headers.key?('System-Token')).to eq true
    expect(response.headers['System-Token'])
      .to match(/^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[ab89][a-f0-9]{3}-[a-f0-9]{12}$/i)
  end
end

shared_examples 'does not respond with a token' do
  it 'does not repond with a token' do
    get :service, params: { id: 1 }

    expect(response.status).to eq 404
    expect(response.headers.key?('System-Token')).to eq false
  end
end

shared_examples 'updates the system token' do
  it 'updates the system token' do
    allow(SecureRandom).to receive(:uuid).and_return(new_system_token)

    expect { get :service, params: { id: 1 } }
      .to change { system.reload.system_token }
      .from(current_system_token).to(new_system_token)
  end
end

shared_examples "does not update the old system's token" do
  it 'does not update the system token' do
    expect { get :service, params: { id: 1 } }
      .not_to change { system.reload.system_token }
  end
end

shared_examples 'creates a duplicate system' do
  it 'creates a new System (duplicate)' do
    allow(SecureRandom).to receive(:uuid).and_return(new_system_token)

    expect { get :service, params: { id: 1 } }
      .to change { System.get_by_credentials(system.login, system.password).count }
      .by(1)

    duplicate_system = System.last

    expect(duplicate_system).not_to eq(system)
    expect(duplicate_system.activations.count).to eq(system.activations.count)
    expect(duplicate_system.system_token).not_to eq(system.system_token)
    expect(duplicate_system.system_token).to eq(new_system_token)
  end
end

shared_examples 'does not create a duplicate system' do
  it 'does not create a new System' do
    expect { get :service, params: { id: 1 } }
      .not_to change(System, :count)
  end
end
