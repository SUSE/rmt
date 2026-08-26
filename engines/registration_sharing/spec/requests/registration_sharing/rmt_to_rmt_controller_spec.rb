require 'rails_helper'
require 'securerandom'

# rubocop:disable Metrics/ModuleLength
module RegistrationSharing
  RSpec.describe RmtToRmtController, type: :request do
    # the controller opens its transaction with an explicit isolation level, and
    # ActiveRecord refuses that inside the transaction that wraps each example
    # ("cannot set transaction isolation in a nested transaction"), so this file
    # cleans up after itself instead
    self.use_transactional_tests = false

    after do
      Activation.delete_all
      System.delete_all
      Service.delete_all
      Product.delete_all
      DeregisteredSystem.delete_all
    end

    let(:login_payg) { SecureRandom.hex }
    let(:login_byos) { SecureRandom.hex }
    let(:password) { SecureRandom.hex }
    let(:created_at) { Time.zone.now.round - 60 }
    let(:registered_at) { created_at + 5 }
    let(:last_seen_at) { created_at + 5 }
    let(:product) { FactoryBot.create(:product, :with_service) }
    let(:api_secret) { 's3cr3tt0k3n' }
    let(:request_token) { api_secret }
    let(:instance_data) { '<document>test</document>' }
    let(:pubcloud_reg_code) { 'INTERNAL-FOO' }

    before do
      expect(RegistrationSharing).not_to receive(:save_for_sharing)
      allow(Settings).to receive(:[]).with(:regsharing).and_return({ api_secret: api_secret })
    end

    describe '#create byos' do
      before do
        allow(System).to receive(:find_or_create_by).with(
          login: login_byos, password: password, system_token: nil
        ).and_call_original

        post(
          '/api/regsharing',
          params: {
            login: login_byos,
            password: password,
            created_at: created_at,
            registered_at: registered_at,
            last_seen_at: last_seen_at,
            proxy_byos_mode: :byos,
            pubcloud_reg_code: pubcloud_reg_code,
            activations: [
              {
                product_id: product.id,
                created_at: created_at
              }
            ],
            instance_data: instance_data
          },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with incorrect credentials' do
        let(:request_token) { 'wr0ngt0k3n' }

        it 'returns an error' do
          expect(response).to have_http_status(401)
        end
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        context 'system' do
          subject(:system) { System.find_by(login: login_byos) }

          it { is_expected.not_to eq(nil) }
          its(:password) { is_expected.to eq(password) }
          its(:created_at) { is_expected.to eq(created_at) }
          its(:registered_at) { is_expected.to eq(registered_at) }
          its(:last_seen_at) { is_expected.to eq(last_seen_at) }
          its(:proxy_byos_mode) { is_expected.to eq('byos') }
          its(:pubcloud_reg_code) { is_expected.to eq('INTERNAL-FOO') }
          it 'saves instance data' do
            expect(system.instance_data).to eq(instance_data)
          end
        end

        context 'activation' do
          subject(:activation) { System.find_by(login: login_byos).activations.first }

          it { is_expected.not_to eq(nil) }
          it 'has correct product_id' do
            expect(activation.product.id).to eq(product.id)
          end
          its(:created_at) { is_expected.to eq(created_at) }
        end
      end
    end

    describe '#create payg' do
      before do
        post(
          '/api/regsharing',
          params: {
            login: login_payg,
            password: password,
            created_at: created_at,
            registered_at: registered_at,
            last_seen_at: last_seen_at,
            proxy_byos_mode: :payg,
            pubcloud_reg_code: pubcloud_reg_code,
            activations: [
              {
                product_id: product.id,
                created_at: created_at
              }
            ],
            instance_data: instance_data
          },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        context 'system' do
          subject(:system) { System.find_by(login: login_payg) }

          it { is_expected.not_to eq(nil) }
          its(:proxy_byos_mode) { is_expected.to eq('payg') }
          it 'saves instance data' do
            expect(system.instance_data).to eq(instance_data)
          end
        end
      end
    end

    describe '#create hybrid' do
      before do
        post(
          '/api/regsharing',
          params: {
            login: login_payg,
            password: password,
            created_at: created_at,
            registered_at: registered_at,
            last_seen_at: last_seen_at,
            proxy_byos_mode: :hybrid,
            pubcloud_reg_code: pubcloud_reg_code,
            activations: [
              {
                product_id: product.id,
                created_at: created_at
              }
            ],
            instance_data: instance_data
          },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        context 'system' do
          subject(:system) { System.find_by(login: login_payg) }

          it { is_expected.not_to eq(nil) }
          its(:proxy_byos_mode) { is_expected.to eq('hybrid') }
          it 'saves instance data' do
            expect(system.instance_data).to eq(instance_data)
          end
        end
      end
    end

    describe 'duplicate race condition' do
      before do
        System.create!(
          login: login_payg,
          password: password,
          system_token: login_payg
        )
        allow(System).to receive(:find_or_create_by).and_raise(ActiveRecord::RecordNotUnique)
        allow(System).to receive(:find_by!).and_call_original
        post(
          '/api/regsharing',
          params: {
            login: login_payg,
            password: password,
            system_token: login_payg,
            created_at: created_at,
            registered_at: registered_at,
            last_seen_at: last_seen_at,
            proxy_byos_mode: :hybrid,
            pubcloud_reg_code: pubcloud_reg_code,
            activations: [
              {
                product_id: product.id,
                created_at: created_at
              }
            ],
            instance_data: instance_data
          },
          headers: { 'Authorization' => "Bearer #{request_token}" }
          )
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        context 'system' do
          subject(:system) { System.find_by(login: login_payg) }

          it { is_expected.not_to eq(nil) }
          its(:proxy_byos_mode) { is_expected.to eq('hybrid') }
          it 'saves instance data' do
            expect(system.instance_data).to eq(instance_data)
          end
        end
      end
    end

    describe 'contention retry' do
      let(:params) do
        {
          login: login_payg,
          password: password,
          created_at: created_at,
          registered_at: registered_at,
          last_seen_at: last_seen_at,
          proxy_byos_mode: :payg,
          activations: [{ product_id: product.id, created_at: created_at }],
          instance_data: instance_data
        }
      end

      before do
        # the backoff has nothing to wait for in a test
        allow_any_instance_of(described_class).to receive(:sleep)
        allow(Rails.logger).to receive(:warn)
      end

      def post_regsharing
        post('/api/regsharing', params: params, headers: { 'Authorization' => "Bearer #{request_token}" })
      end

      # raises on the first 'failures' calls, then behaves normally
      def fail_first(error, failures)
        calls = 0
        allow(System).to receive(:find_or_create_by).and_wrap_original do |original, *args|
          calls += 1
          raise error if calls <= failures

          original.call(*args)
        end
      end

      {
        'a deadlock' => ActiveRecord::Deadlocked,
        'a lock wait timeout' => ActiveRecord::LockWaitTimeout
      }.each do |description, error_class|
        context "when #{description} clears on the second attempt" do
          before do
            fail_first(error_class.new('contention'), 1)
            post_regsharing
          end

          it 'performs HTTP request successfully' do
            expect(response).to have_http_status(204)
          end

          it 'creates the system' do
            expect(System.find_by(login: login_payg)).not_to eq(nil)
          end

          it 'creates the activation' do
            expect(System.find_by(login: login_payg).activations.count).to eq(1)
          end

          it 'logs the retry' do
            expect(Rails.logger).to have_received(:warn)
                                      .with(/#{error_class}.*attempt 1\/#{described_class::DEADLOCK_RETRIES}/)
          end
        end
      end

      context 'when the contention does not clear' do
        before { fail_first(ActiveRecord::Deadlocked.new('contention'), described_class::DEADLOCK_RETRIES) }

        it 'lets the error through' do
          expect { post_regsharing }.to raise_error(ActiveRecord::Deadlocked)
        end

        it 'stops after DEADLOCK_RETRIES attempts' do
          expect { post_regsharing }.to raise_error(ActiveRecord::Deadlocked)
          expect(System).to have_received(:find_or_create_by).exactly(described_class::DEADLOCK_RETRIES).times
        end

        it 'does not persist the system' do
          expect { post_regsharing }.to raise_error(ActiveRecord::Deadlocked)
          expect(System.find_by(login: login_payg)).to eq(nil)
        end
      end

      context 'when the error is not contention' do
        before { fail_first(ActiveRecord::RecordNotFound.new('missing'), 1) }

        it 'does not retry' do
          expect { post_regsharing }.to raise_error(ActiveRecord::RecordNotFound)
          expect(System).to have_received(:find_or_create_by).once
        end
      end
    end


    describe '#destroy' do
      let!(:system) { FactoryBot.create(:system) }

      before do
        delete(
          '/api/regsharing',
          params: { login: system.login },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with incorrect credentials' do
        let(:request_token) { 'wr0ngt0k3n' }

        it 'returns an error' do
          expect(response).to have_http_status(401)
        end
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        it 'removes the system' do
          expect { System.find(system.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
